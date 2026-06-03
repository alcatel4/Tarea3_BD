import pyodbc

DB_CONFIG = {
    'server':   'localhost',
    'database': 'tarea3',
    'driver':   'ODBC Driver 17 for SQL Server',
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