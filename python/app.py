from flask import Flask
from login import login_bp
from adminhome import admin_bp
from emplhome import homeEmpl_bp
from adminEditarEmpl import editar_bp

app = Flask(__name__)
app.secret_key = 'tarea3itcr'

app.register_blueprint(login_bp)
app.register_blueprint(homeEmpl_bp)
app.register_blueprint(admin_bp)
app.register_blueprint(editar_bp)

if __name__ == '__main__':
    app.run(debug=True)