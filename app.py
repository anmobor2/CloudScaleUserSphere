import os
from flask import Flask, flash, redirect, render_template, request, url_for
from flask_login import LoginManager, UserMixin, current_user, login_required, login_user, logout_user
from flask_sqlalchemy import SQLAlchemy
from flask_session import Session
import redis
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
#from dotenv import load_dotenv
from werkzeug.security import check_password_hash, generate_password_hash
from forms import LoginForm, SignupForm

app = Flask(__name__)

# Azure Key Vault URL
key_vault_url = os.getenv('KEY_VAULT_URL', 'https://<your-keyvault-name>.vault.azure.net/')

# Use DefaultAzureCredential to authenticate using Managed Identity
credential = DefaultAzureCredential()

# Initialize the SecretClient for Key Vault
secret_client = SecretClient(vault_url=key_vault_url, credential=credential)

#Fetch secrets from Key Vault
app.config['SECRET_KEY'] = secret_client.get_secret("SECRET_KEY").value
app.config['SQLALCHEMY_DATABASE_URI'] = secret_client.get_secret("DATABASE_URL").value
redis_url = secret_client.get_secret("REDIS_URL").value

# Configure Redis for session management

app.config['SESSION_TYPE'] = 'redis'
app.config['SESSION_PERMANENT'] = False
app.config['SESSION_USE_SIGNER'] = True
app.config['SESSION_REDIS'] = redis.from_url(redis_url)
Session(app)

db = SQLAlchemy(app)
login_manager = LoginManager(app)
login_manager.login_view = 'login'

class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(100), unique=True, nullable=False)
    password = db.Column(db.String(200), nullable=False)
    email = db.Column(db.String(100), unique=True, nullable=False)

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    form = LoginForm()  # Instantiate the form

    if form.validate_on_submit():
        username = form.username.data
        password = form.password.data

        # Query the user by username
        user = User.query.filter_by(username=username).first()

        # Check if the user exists and the password is correct
        if user and check_password_hash(user.password, password):
            login_user(user)  # Log the user in
            return redirect(url_for('profile'))  # Redirect to the profile page

        flash('Invalid username or password')

    # If the request method is GET or the form is invalid, render the login page
    return render_template('login.html', form=form)


@app.route('/signup', methods=['GET', 'POST'])
def signup():
    form = SignupForm()

    if form.validate_on_submit():
        username = form.username.data
        email = form.email.data
        password = form.password.data

        # Check if the user already exists
        user = User.query.filter_by(username=username).first()
        if user:
            flash('Username already exists. Please choose a different one.')
        else:
            # Hash the password using a supported method
            hashed_password = generate_password_hash(password, method='pbkdf2:sha256')
            new_user = User(username=username, email=email, password=hashed_password)
            db.session.add(new_user)
            db.session.commit()
            flash('Sign up successful! You can now log in.')
            return redirect(url_for('login'))

    return render_template('signup.html', form=form)

@app.route('/profile')
@login_required
def profile():
    return render_template('profile.html', user=current_user)

@app.route('/logout')
@login_required
def logout():
    logout_user()
    return redirect(url_for('index'))

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run( host='0.0.0.0', port=int(os.getenv('PORT', 8000)))