from server.api import APIServer

def main():
    var server = APIServer(8080)
    server.start()
