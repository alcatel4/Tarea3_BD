import pyodbc
from flask import Flask

app = Flask(__name__)

# Configuracion de conexion
DB_CONFIG = {
    'server': 'localhost',
    'database': 'tarea3',
    'driver': 'ODBC Driver 17 for SQL Server',
    'username': 'usuarioremoto',
    'password': 'tarea123'
}

def get_connection():
    conn = pyodbc.connect(
        f"DRIVER={{{DB_CONFIG['driver']}}};"
        f"SERVER={DB_CONFIG['server']};"
        f"DATABASE={DB_CONFIG['database']};"
        f"UID={DB_CONFIG['username']};"
        f"PWD={DB_CONFIG['password']};"
    )
    return conn

try:
    conn = get_connection()
    print("Conexion exitosa")
    conn.close()
except Exception as e:
    print(f"Error: {str(e)}")

if __name__ == '__main__':
    app.run(debug=True)