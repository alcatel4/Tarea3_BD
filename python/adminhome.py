from flask import Blueprint, request, session, redirect
from db import get_connection

admin_bp = Blueprint('admin', __name__)

@admin_bp.route('/homeAdmin')
def home_admin():
    if session.get('tipo') != 1:
        return redirect('/login')

    filtro = request.args.get('filtro', '')

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute(
        "DECLARE @outResultCode INT; EXEC dbo.procListarEmpleados ?, ?, ?, @outResultCode OUTPUT",
        filtro, session.get('username'), request.remote_addr
    )

    filas = ''
    for row in cursor.fetchall():
        filas += f'''
        <tr>
            <td>{row[1]}</td>
            <td>{row[2]}</td>
            <td>
                <a class="btn-accion btn-editar" href="/editar/{row[0]}">Editar</a>
                <a class="btn-accion btn-impersonar" href="/impersonar/{row[0]}">Impersonar</a>
            </td>
        </tr>
        '''

    conn.commit()
    cursor.close()
    conn.close()

    with open('html/homeAdmin.html', 'r', encoding='utf-8') as f:
        html = f.read()

    html = html.replace('<!--FILAS-->', filas)
    html = html.replace('<!--FILTRO-->', filtro)
    return html