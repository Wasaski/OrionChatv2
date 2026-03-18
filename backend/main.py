import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from pydantic import BaseModel
import requests
import json
import sqlite3

app = FastAPI()

# Banco de dados simples para chaves públicas
def init_db():
    conn = sqlite3.connect('orion.db')
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS users 
                 (username TEXT PRIMARY KEY, pub_key TEXT)''')
    conn.commit()
    conn.close()

init_db()

class User(BaseModel):
    username: str
    pub_key: str

@app.post("/register")
async def register(user: User):
    conn = sqlite3.connect('orion.db')
    c = conn.cursor()
    try:
        c.execute("INSERT INTO users VALUES (?,?)", (user.username, user.pub_key))
        conn.commit()
        return {"status": "User registered"}
    except:
        raise HTTPException(status_code=400, detail="User already exists")
    finally:
        conn.close()

@app.get("/get_key/{username}")
async def get_key(username: str):
    conn = sqlite3.connect('orion.db')
    c = conn.cursor()
    c.execute("SELECT pub_key FROM users WHERE username=?", (username,))
    res = c.fetchone()
    conn.close()
    if res: return {"pub_key": res[0]}
    raise HTTPException(status_code=404, detail="User not found")

# --- ANONPAY INTEGRATION ---
@app.post("/donate/{method}")
async def donate(method: str, amount: float):
    # SUA CHAVE FICA AQUI, LONGE DO APK
    SECRET = "SUA_SECRET_KEY_ANONPAY" 
    headers = {"Authorization": f"Bearer {SECRET}"}
    payload = {"amount": amount, "currency": "BRL", "method": method}
    r = requests.post("https://api.anonpay.de/api/v1/orders", json=payload, headers=headers)
    return r.json()

# --- WEBSOCKET RELAY (E2EE) ---
class ConnectionManager:
    def __init__(self):
        self.active_connections: dict = {}

    async def connect(self, websocket: WebSocket, user: str):
        await websocket.accept()
        self.active_connections[user] = websocket

    def disconnect(self, user: str):
        if user in self.active_connections: del self.active_connections[user]

    async def send_to(self, message: str, to_user: str):
        if to_user in self.active_connections:
            await self.active_connections[to_user].send_text(message)

manager = ConnectionManager()

@app.websocket("/ws/{username}")
async def websocket_endpoint(websocket: WebSocket, username: str):
    await manager.connect(websocket, username)
    try:
        while True:
            data = await websocket.receive_text()
            msg_obj = json.loads(data)
            # O servidor apenas repassa o 'ciphertext' sem conseguir ler
            await manager.send_to(data, msg_obj['to'])
    except WebSocketDisconnect:
        manager.disconnect(username)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
