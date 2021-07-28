# Drone CI 管道配置入门
以 `golang` 项目为例子，结合 `Drone CI` 实现项目的自动化测试，打包，部署并发布到目标机器的全流程，最后发出通知邮件。在 `Drone CI` 中很多的工具已经提供了容器化插件工具，十分便利，另外它的设计就是原生支持容器化，让流程更加简化。不足的就是其文档可读性和时效性都有待提高，在完成这个配置过程中需要借助大量辅助文档，比较费时费力。

### 项目结构

```bash
play-with-drone-ci
├── LICENSE
├── README.md
├── api
│   ├── app.go
│   └── model.go
├── cicd
│   ├── Dockerfile
│   ├── build_app.sh
│   ├── deploy_services.sh
│   ├── docker-compose.yml
│   └── test_api.sh
├── .drone.yml
├── doc_imges
├── go.mod
├── go.sum
├── main.go
├── main_test.go
└── www
    └── index.html
```

* `cicd` 项目部署使用的到文件都在这里，方便统一管理；

* `.drone.yml` 为 `Drone CI` 的配置文件，包含 管道配置，后台服务配置，触发器配置等。

### Drone CI 配置示例说明

管道配置编写有一个固定的开头和结束，这些直接看官方的参考文档即可：https://docs.drone.io/quickstart/docker/。

#### 配置自动化测试

自动化测试中需要使用到 `mongodb`，所以使用 `Drone CI` 服务（`services`）启动一个 `Docker` 容器作为测试用的服务器，同时 在`steps` 中的名为`test monogo service` 中配置了容器测试 `mongodb` 容器服务是否正确启动。接着是名为`test app`的步骤，这里是利用 `golang` 容器，并到 `cicd` 目录中执行 `test_api.sh` 脚本开始测试。

```yaml
---
kind: pipeline
type: docker
name: company-test

steps:
- name: test monogo service
  image: mongo:latest
  commands:
  - sleep 3
  - mongo --host mgo --eval "{ping:1}"

- name: test app
  image: golang:latest
  environment:
    BRC: ${DRONE_COMMIT_BRANCH}
    SHA: ${DRONE_COMMIT_SHA:0:8}
    EVN: ${DRONE_BUILD_EVENT}
    MSG: ${DRONE_COMMIT_MESSAGE}
    TAG: ${DRONE_TAG}
    MGO: mgo:27017
  volumes:
  - name: deps
    path: /go
  commands:
  - cd cicd
  - /bin/sh test_api.sh $MGO $BRC $SHA $EVN $MSG $TAG
  
services:
- name: mgo
  image: mongo:latest

volumes:
- name: deps
  temp: {}
```

> volumes 中提供 `deps` 临时文件映射，那么 `golang`的依赖包可以被其它容器共用。

#### 配置自动构建流程

配置一个新的容器，并添加 `deps` 卷共用 `/go` 目录可以不用重新下载依赖包，加速构建过程。具体构建过程可以查看源码目录中的 `build_app.sh` 脚本。配置里面加入触发的条件，就是在 `git` 中打上标签事件才会触发到这个步骤，否则不会执行这个步骤。

```yaml
- name: build app
  image: golang:latest
  volumes:
  - name: deps
    path: /go
  commands:
  - cd cicd
  - /bin/sh build_app.sh
  when:
    event: [tag]
```

#### 配置自动镜像打包和上传流程

这里借助的官方提供的一个特殊镜像 `plugins/docker` ，记得配置要写在 `settings` 下，否则不会生效。使用说明可以参考这个插件的说明文档：http://plugins.drone.io/drone-plugins/drone-docker/。这里需要用到一些账号和密码之类的敏感信息，可用 `secrets` 功能保存在 `Drone CI` 上，然后使用 `from_secret `在配置文件中引入，避免敏感信息泄露，配置过程可以参考：https://docs.drone.io/secret/。

```yaml
- name: build and push image
  image: plugins/docker
  settings:
    repo: registry.example.com/test/go-app
    registry: registry.example.com
    username:
      from_secret: DOCKER_USERNAME
    password:
      from_secret: DOCKER_PASSWORD
    context: ./cicd
    dockerfile: ./cicd/Dockerfile
    tags:
      - latest
      - ${DRONE_TAG}
  when:
    event: [tag]
```

#### 配置自动部署和发布流程

使用插件镜像 `appleboy/drone-scp` 和 `appleboy/drone-ssh`，首先复制构建好的文件和必要的部署文件到目标部署机器，然后借助远程 `ssh`方式登陆目标机器进行部署和发布工作，具体的执行可以查看源代码中的`deploy_services.sh` 脚本文件 。敏感信息同样使用`Drone CI`提供的 `secrets` 功能保存后再引入。

* `appleboy/drone-scp` 使用指南：http://plugins.drone.io/appleboy/drone-scp/
* `appleboy/drone-ssh` 使用指南：http://plugins.drone.io/appleboy/drone-ssh/

```yaml
- name: scp tar to target host
  image: appleboy/drone-scp
  settings:
    host:
      - target.example.com
    username:
      from_secret: HOST_USERNAME
    password:
      from_secret: HOST_PASSWORD
    port: 22
    target: /home/workspace/service/api-server
    source: ./cicd/release.tar.gz
  when:
    event: [tag]

- name: deploy app
  image: appleboy/drone-ssh
  settings:
    host:
      - target.example.com
    username:
      from_secret: HOST_USERNAME
    password:
      from_secret: HOST_PASSWORD
    port: 22
    script_stop: true
    script:
      - cd /home/workspace/service/api-server/cicd
      - tar -zxvf release.tar.gz
      - ls -l
      - /bin/sh deploy_services.sh ${DRONE_TAG} ${DRONE_COMMIT_SHA:0:8}
  when:
    event: [tag]
```

#### 配置CI执行状态通知流程

`Drone CI` 的通知组件提供了许多的方式：`facebook` 、`slask` 、`dingtalk`、 `wechat`、`email`等，可以在这里找到可以使用的通知插件：http://plugins.drone.io/。目前主要是使用 `Email` 的方式，使用 `drillster/drone-email` 插件，使用指南参考：https://github.com/Drillster/drone-email/blob/master/DOCS.md，配置相应的 `stmp` 服务配置，账号和密码敏感信息通过 `from_secret` 引入。

```yaml
- name: notify
  image: drillster/drone-email
  settings:
    from: notify@example.com
    host: smtp.example.com
    port: 465
    username:
      from_secret: SMTP_USERNAME
    password:
      from_secret: SMTP_PASSWORD
    recipients:
      - toolman@example.com
```

### 总结

利用 `Drone CI` 在经过简单配置过就可以使用自动测试，构建，部署和发布流程。后续可以继续学习并研究`Drone CI` 多管道配置流程，并向不同编程语言中使用。

### 附录

* [源代码](https://github.com/ouranoshong/play-with-drone-ci)
* [Drone CI 默认环境变量](https://docs.drone.io/pipeline/environment/reference/)

