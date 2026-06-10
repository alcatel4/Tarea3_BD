from flask import Blueprint, request, session, redirect, jsonify
from db import get_connection

homeEmpl_bp = Blueprint('homeEmpl', __name__)


def get_id_empleado(username):
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        "DECLARE @outResultCode INT; EXEC dbo.procObtenerEmpleadoPorUsuario ?, @outResultCode OUTPUT",
        username
    )
    row = cursor.fetchone()
    cursor.close()
    conn.close()
    return row  # (idEmpleado, Nombre)


@homeEmpl_bp.route('/homeEmpl')
def home_empl():
    if session.get('tipo') != 2:
        return redirect('/login')

    username = session.get('username')
    ip = request.remote_addr

    # Obtener idEmpleado y nombre
    row_empl = get_id_empleado(username)
    id_empleado = row_empl[0]
    nombre_empl = row_empl[1]

    conn = get_connection()
    cursor = conn.cursor()

    # ── Planillas semanales ──
    cursor.execute(
        "DECLARE @outResultCode INT; EXEC dbo.procConsultarPlanillasSemanal ?, ?, ?, @outResultCode OUTPUT",
        id_empleado, username, ip
    )

    filas_semanal = ''
    for row in cursor.fetchall():
        id_semana = row[0]
        fecha_inicio = row[1]
        fecha_fin = row[2]
        bruto = row[3]
        deducciones = row[4]
        neto = row[5]
        h_ord = row[6]
        h_ext_n = row[7]
        h_ext_d = row[8]
        label = f"{fecha_inicio} – {fecha_fin}"

        filas_semanal += f'''
        <tr>
            <td>{label}</td>
            <td>
                <button class="clickable"
                    onclick="abrirModalBruto({id_semana}, '{label}')">
                    &#8353; {bruto}
                </button>
            </td>
            <td>
                <button class="clickable"
                    onclick="abrirModalDedSemanal({id_semana}, '{label}')">
                    &#8353; {deducciones}
                </button>
            </td>
            <td>&#8353; {neto}</td>
            <td>{h_ord}</td>
            <td>{h_ext_n}</td>
            <td>{h_ext_d}</td>
        </tr>
        '''

    conn.commit()
    cursor.close()

    # ── Planillas mensuales ──
    cursor2 = conn.cursor()
    cursor2.execute(
        "DECLARE @outResultCode INT; EXEC dbo.procConsultarPlanillasMensual ?, ?, ?, @outResultCode OUTPUT",
        id_empleado, username, ip
    )

    filas_mensual = ''
    for row in cursor2.fetchall():
        id_mes = row[0]
        fecha_inicio = row[1]
        fecha_fin = row[2]
        bruto = row[3]
        deducciones = row[4]
        neto = row[5]
        label = f"{fecha_inicio} – {fecha_fin}"

        filas_mensual += f'''
        <tr>
            <td>{label}</td>
            <td>&#8353; {bruto}</td>
            <td>
                <button class="clickable"
                    onclick="abrirModalDedMensual({id_mes}, '{label}')">
                    &#8353; {deducciones}
                </button>
            </td>
            <td>&#8353; {neto}</td>
        </tr>
        '''

    conn.commit()
    cursor2.close()
    conn.close()

    # ── Botón volver (solo si está impersonando) ──
    boton_volver = ''
    if session.get('impersonando'):
        boton_volver = '<a class="btn-volver" href="/volverAdmin">Volver a Admin</a>'

    with open('html/homeEmpl.html', 'r', encoding='utf-8') as f:
        html = f.read()

    html = html.replace('<!--NOMBRE_EMPLEADO-->', nombre_empl)
    html = html.replace('<!--BOTON_VOLVER-->', boton_volver)
    html = html.replace('<!--FILAS_SEMANAL-->', filas_semanal)
    html = html.replace('<!--FILAS_MENSUAL-->', filas_mensual)
    return html


@homeEmpl_bp.route('/detalleSemanal')
def detalle_semanal():
    if session.get('tipo') != 2:
        return redirect('/login')

    id_planilla_semanal = request.args.get('idSemana')
    username = session.get('username')
    ip = request.remote_addr

    conn   = get_connection()
    cursor = conn.cursor()

    cursor.execute(
        "DECLARE @outResultCode INT; EXEC dbo.procConsultarDetalleSemanal ?, ?, ?, @outResultCode OUTPUT",
        id_planilla_semanal, username, ip
    )

    resultado = []
    for row in cursor.fetchall():
        resultado.append({
            'fecha': row[0],
            'entrada': row[1],
            'salida': row[2],
            'tipo': row[3],
            'horas': float(row[4]),
            'monto': float(row[5])
        })

    conn.commit()
    cursor.close()
    conn.close()

    return jsonify(resultado)


@homeEmpl_bp.route('/deduccionesSemanal')
def deducciones_semanal():
    if session.get('tipo') != 2:
        return redirect('/login')

    id_planilla_semanal = request.args.get('idSemana')
    username = session.get('username')
    ip = request.remote_addr

    conn   = get_connection()
    cursor = conn.cursor()

    cursor.execute(
        "DECLARE @outResultCode INT; EXEC dbo.procConsultarDeduccionesSemanal ?, ?, ?, @outResultCode OUTPUT",
        id_planilla_semanal, username, ip
    )

    resultado = []
    for row in cursor.fetchall():
        resultado.append({
            'nombre': row[0],
            'porcentaje': row[1],
            'monto': float(row[2])
        })

    conn.commit()
    cursor.close()
    conn.close()

    return jsonify(resultado)


@homeEmpl_bp.route('/deduccionesMensual')
def deducciones_mensual():
    if session.get('tipo') != 2:
        return redirect('/login')

    id_planilla_mensual = request.args.get('idMes')
    username = session.get('username')
    ip = request.remote_addr

    conn   = get_connection()
    cursor = conn.cursor()

    cursor.execute(
        "DECLARE @outResultCode INT; EXEC dbo.procConsultarDeduccionesMensual ?, ?, ?, @outResultCode OUTPUT",
        id_planilla_mensual, username, ip
    )

    resultado = []
    for row in cursor.fetchall():
        resultado.append({
            'nombre': row[0],
            'porcentaje': row[1],
            'monto': float(row[2])
        })

    conn.commit()
    cursor.close()
    conn.close()

    return jsonify(resultado)


@homeEmpl_bp.route('/volverAdmin')
def volver_admin():
    if not session.get('impersonando'):
        return redirect('/login')

    session['username'] = session.pop('username_admin')
    session['tipo'] = 1
    session['impersonando'] = False

    return redirect('/homeAdmin')