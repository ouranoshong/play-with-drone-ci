package main

import (
	"flag"

	"demo/api"
)

func init() {
	flag.StringVar(&api.DBName, "db_name", "mgo", "mongo name")
	flag.StringVar(&api.DBAddr, "db_addr", "localhost:27017", "mongo addr")
	flag.StringVar(&api.Addr, "port", "8090", "http server port")
}

func main() {
	flag.Parse()
	app := api.NewApp()
	app.InitMgo(api.DBName, api.DBAddr)
	app.Run(api.Addr)
}
