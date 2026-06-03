from flask import Blueprint, request, session, redirect
from db import get_connection

login_bp = Blueprint('login', __name__)

@login_bp.route('/')
def index():
    return redirect('/login')

@login_bp.route('/login', methods=['GET'])
def login():
    with open('html/login.html', 'r', encoding='utf-8') as f:
        html = f.read()
    return html

@login_bp.route('/login', methods=['POST'])
def do_login():
    username = request.form.get('username')
    password = request.form.get('password')
    ip = request.remote_addr

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute(
        "DECLARE @outResultCode INT; EXEC dbo.procLogin ?, ?, ?, @outResultCode OUTPUT; SELECT @outResultCode",
        username, password, ip
    )

    row = cursor.fetchone()
    resultCode = row[0]
    print(f"resultCode: {resultCode}")
    conn.commit()
    cursor.close()

    if resultCode != 0:
        conn.close()
        with open('html/login.html', 'r', encoding='utf-8') as f:
            html = f.read()
        html = html.replace(
            '<!--ERROR-->',
            '<p style="color:red; text-align:center; margin-top:15px;">Usuario o password incorrecto</p>'
        )
        return html

    cursor2 = conn.cursor()
    cursor2.execute(
        "DECLARE @outResultCode INT; EXEC dbo.procObtenerTipoUsuario ?, @outResultCode OUTPUT; SELECT @outResultCode",
        username
    )

    row2 = cursor2.fetchone()
    tipo = row2[0]
    print(f"tipo: {tipo}")
    cursor2.close()
    conn.close()

    session['username'] = username
    session['tipo'] = tipo

    if tipo == 1:
        return redirect('/homeAdmin')
    else:
        return redirect('/homeEmpl')