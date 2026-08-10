 
from flask import render_template, request, redirect, session
from app import app
from app.models import insert_user, validate_user
 
@app.route('/')
def index():
    return render_template('index.html')
 
@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        name = request.form['name']
        email = request.form['email']
        password = request.form['password']
        insert_user(name, email, password)
        return redirect('/')
    return render_template('register.html')
 
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        email = request.form['email']
        password = request.form['password']
        user = validate_user(email, password)
        if user:
            session['loggedin'] = True
            return redirect('/')
        else:
            return "Login Failed"
    return render_template('login.html')
 