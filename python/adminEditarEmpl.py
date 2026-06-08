from flask import Blueprint, request, session, redirect
from db import get_connection

editar_bp = Blueprint('editar', __name__)

@editar_bp.route('/editar/<int:id_empleado>', methods=['GET'])
def editar(id_empleado):
    if session.get('tipo') != 1:
        return redirect('/login')

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute(
        "DECLARE @outResultCode INT; EXEC dbo.procObtenerEmpleado ?, @outResultCode OUTPUT",
        id_empleado
    )

    row = cursor.fetchone()
    cursor.close()

    cursor2 = conn.cursor()
    cursor2.execute(
        "DECLARE @outResultCode INT; EXEC dbo.procObtenerPuestos @outResultCode OUTPUT"
    )

    puestos = ''
    for p in cursor2.fetchall():
        selected = 'selected' if p[0] == row[5] else ''
        puestos += f'<option value="{p[0]}" {selected}>{p[1]}</option>'

    cursor2.close()
    conn.close()

    with open('html/editarEmpleadoAdmin.html', 'r', encoding='utf-8') as f:
        html = f.read()

    html = html.replace('<!--ID-->', str(id_empleado))
    html = html.replace('<!--NOMBRE-->', row[1])
    html = html.replace('<!--TIPO_DOC-->', row[2])
    html = html.replace('<!--DOCUMENTO-->', row[3])
    html = html.replace('<!--CUENTA-->', row[4])
    html = html.replace('<!--PUESTOS-->', puestos)
    html = html.replace('<!--FECHA_CONTRATACION-->', str(row[7]))

    return html

@editar_bp.route('/editar/<int:id_empleado>', methods=['POST'])
def editar_post(id_empleado):
    if session.get('tipo') != 1:
        return redirect('/login')

    nombre = request.form.get('nombre')
    tipo_doc = request.form.get('tipoDocumento')
    documento = request.form.get('documentoIdentidad')
    cuenta = request.form.get('cuentaBancaria')
    id_puesto = request.form.get('idPuesto')

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute(
        "DECLARE @outResultCode INT; EXEC dbo.procEditarEmpleado ?, ?, ?, ?, ?, ?, ?, ?, @outResultCode OUTPUT",
        id_empleado, nombre, tipo_doc, documento, cuenta, id_puesto, session.get('username'), request.remote_addr
    )

    conn.commit()
    cursor.close()
    conn.close()

    return redirect('/homeAdmin')