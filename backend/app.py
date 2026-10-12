import datetime
import socket

from flask import Flask, jsonify

app = Flask(__name__)


@app.get("/api/hello")
def hello():
    return jsonify(
        message="Привет от бэкенда!",
        hostname=socket.gethostname(),
        time=datetime.datetime.now().isoformat(timespec="seconds"),
    )


@app.get("/api/health")
def health():
    return jsonify(status="ok")
