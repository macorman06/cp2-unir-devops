import os
from flask import Flask, jsonify

app = Flask(__name__)
COUNTER_FILE = "/data/counter.txt"

def read_counter():
    try:
        with open(COUNTER_FILE) as f:
            return int(f.read().strip())
    except (FileNotFoundError, ValueError):
        return 0

def write_counter(n):
    os.makedirs(os.path.dirname(COUNTER_FILE), exist_ok=True)
    with open(COUNTER_FILE, "w") as f:
        f.write(str(n))

@app.route("/")
def index():
    return """<!DOCTYPE html>
<html>
<head>
  <title>Contador Persistente</title>
</head>
<body style="font-family:sans-serif;text-align:center;padding:4rem">
  <h1>Contador Persistente</h1>
  <p style="font-size:4rem;margin:2rem 0" id="counter">0</p>
  <button onclick="fetch('/click',{method:'POST'}).then(r=>r.json()).then(d=>document.getElementById('counter').textContent=d.clicks)" style="font-size:2rem;padding:1rem 2rem">Click</button>
  <p style="margin-top:3rem;color:#666">Los clicks persisten aunque el pod se reinicie</p>
</body>
</html>"""

@app.route("/counter")
def get_counter():
    return jsonify({"clicks": read_counter()})

@app.route("/click", methods=["POST"])
def click():
    n = read_counter() + 1
    write_counter(n)
    return jsonify({"clicks": n})

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
