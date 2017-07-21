from flask import Flask, render_template
from werkzeug.contrib.cache import SimpleCache
import hvac
import os
import json
app = Flask(__name__)
cache = SimpleCache(default_timeout=0)

def vault_client_setup():
    try:
        client
    except NameError:
        client = hvac.Client(url='http://vault:8200')
        if not client.is_authenticated():
            if not cache.get('token'):
                role_id_info = client.unwrap(os.environ['VAULT_ROLE_ID_TOKEN'])
                secret_id_info = client.unwrap(os.environ['VAULT_SECRET_ID_TOKEN'])
                auth_response = client.auth_approle(role_id_info['data']['role_id'], secret_id_info['data']['secret_id'])
                cache.set('token', auth_response['auth']['client_token'])
            client.token = cache.get('token')
    finally:
        return client

@app.route('/')
def default_page():
    client = vault_client_setup()
    result = client.read('database/creds/bachmanity_insanity-readonly')
    return render_template('index.html', result=json.dumps(result))

@app.route('/<string:page_name>/')
def static_page(page_name):
    return render_template('pages/%s.html' % page_name)

if __name__ == "__main__":
    app.run(host='0.0.0.0', debug=True)
