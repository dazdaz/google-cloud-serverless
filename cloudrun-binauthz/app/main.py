#!/usr/bin/env python3
"""
Simple Flask application for Binary Authorization demo.
This app demonstrates that only signed container images can be deployed to Cloud Run.
"""

from flask import Flask, jsonify
import os
import datetime

app = Flask(__name__)

@app.route('/')
def hello():
    """Main endpoint - returns a success message."""
    return jsonify({
        'message': '✓ Success! This container image was verified by Binary Authorization',
        'status': 'authenticated',
        'timestamp': datetime.datetime.utcnow().isoformat(),
        'service': os.environ.get('K_SERVICE', 'local'),
        'revision': os.environ.get('K_REVISION', 'local')
    })

@app.route('/health')
def health():
    """Health check endpoint."""
    return jsonify({'status': 'healthy'}), 200

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
