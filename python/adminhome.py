from flask import Blueprint

admin_bp = Blueprint('admin', __name__)

@admin_bp.route('/homeAdmin')
def home_admin():
    with open('html/homeAdmin.html', 'r', encoding='utf-8') as f:
        html = f.read()
    return html