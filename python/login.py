from flask import Blueprint, render_template, request, redirect, session
from app import get_connection

login_bp = Blueprint('login', __name__)

@login_bp.route('/')
def index():
    return redirect('/login')

@login_bp.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'GET':
        return render_template('login.html')

    username = request.form['username']
    password = request.form['password']
    ip = request.remote_addr

    try:
        conn = get_connection()
        cursor = conn.cursor()

        cursor.execute("EXEC dbo.procLogin ?, ?, ?", username, password, ip)

        row = cursor.fetchone()
        tipo = row[0]  # TipoUsuario
        resultCode = row[1]  # ResultCode
        conn.close()

        if resultCode != 0:
            return render_template('login.html', error='Usuario o password incorrecto')

        session['username'] = username
        session['tipo'] = tipo

        if tipo == 1:# Admin
            return redirect('/admin')
        else: # Empleado
            return redirect('/empleado')

    except Exception as e:
        return render_template('login.html', error=f'Error: {str(e)}')

