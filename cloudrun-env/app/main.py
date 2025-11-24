import os
from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/')
def get_env_vars():
    """
    Returns specific environment variables to demonstrate how they were set.
    """
    # List of keys we care about for this demo
    keys = [
        'APP_ENV',
        'DB_HOST',
        'DB_PORT',
        'API_KEY',
        'FEATURE_FLAG_X',
        'MAINTENANCE_MODE'
    ]
    
    env_vars = {key: os.environ.get(key, 'NOT_SET') for key in keys}
    
    return jsonify({
        'message': 'Environment Variables Demo',
        'environment_variables': env_vars,
        'deployment_method': os.environ.get('DEPLOYMENT_METHOD', 'unknown')
    })

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)