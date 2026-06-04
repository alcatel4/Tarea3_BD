from flask import Blueprint, session, redirect

homeEmpl_bp = Blueprint('homeEmpl', __name__)

@homeEmpl_bp.route('/homeEmpl')
def home_empl():
    if session.get('tipo') != 2:
        return redirect('/login')

    with open('html/homeEmpl.html', 'r', encoding='utf-8') as f:
        html = f.read()
    return html