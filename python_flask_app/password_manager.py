from flask import Flask, render_template
from werkzeug.contrib.cache import SimpleCache
import hvac
import os
import json
app = Flask(__name__)
cache = SimpleCache(default_timeout=0)

TOKEN_MAX = 10
SECRET_MAX = 20

@app.route('/')
def default_page():
    try:
        client
    except NameError:
        client = hvac.Client(url='http://vault:8200')
    if not client.is_authenticated():
        if not cache.get('token'):
            role_id_info = client.unwrap(os.environ['VAULT_ROLE_ID_TOKEN'])
            secret_id_info = client.unwrap(os.environ['VAULT_SECRET_ID_TOKEN'])
            auth_response = client.auth_approle(role_id_info['data']['role_id'], secret_id_info['data']['secret_id'])
            cache.set('TOKEN_COUNT', 0)
            cache.set('SECRET_COUNT', 0)
            cache.set('token', auth_response['auth']['client_token'])
            cache.set('lease_id', secret_id_info['data']['secret_id'])
        client.token = cache.get('token')
    result = client.read('database/creds/bachmanity_insanity-readonly')
    if cache.get('SECRET_COUNT') == SECRET_MAX and cache.get('TOKEN_COUNT') == (TOKEN_MAX - 2):
        lease_id = client.renew_secret(lease_id=cache.get('lease_id'))['lease_id']
        cache.set('lease_id', lease_id)
        token_renewal = client.renew_token()
        cache.set('token', token_renewal['auth']['client_token'])
        cache.set('SECRET_COUNT', 0)
        cache.set('TOKEN_COUNT', 0)
    elif cache.get('TOKEN_COUNT') == (TOKEN_MAX - 1):
        token_renewal = client.renew_token()
        cache.set('token', token_renewal['auth']['client_token'])
        cache.set('TOKEN_COUNT', 0)
    else:
        for i in ['TOKEN_COUNT', 'SECRET_COUNT']:
            val = cache.get(i)
            cache.set(i, val + 1)
    return render_template('index.html', result=json.dumps(result))

@app.route('/<string:page_name>/')
def static_page(page_name):
    return render_template('pages/%s.html' % page_name)

if __name__ == "__main__":
    app.run(host='0.0.0.0', debug=True)
