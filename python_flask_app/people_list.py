from flask import Flask, render_template, request
from werkzeug.contrib.cache import SimpleCache
import time
import hvac
import os
import json
import psycopg2
import psycopg2.extras
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
    return client

@app.route('/', methods=['GET', 'POST'])
def default_page():
    client = vault_client_setup()
    if cache.get('db_creds_result') and int(time.time()) < (cache.get('db_creds_expiry') - 10):
        result = json.loads(cache.get('db_creds_result'))
    else:
        result = client.read('database/creds/bachmanity_insanity-readwrite')
        cache.set('db_creds_result', json.dumps(result))
        cache.set('db_creds_expiry', int(time.time()+result["lease_duration"]))

    try:
        conn = psycopg2.connect(dbname='bachmanity_insanity', user=result['data']['username'], host='postgresql', password=result['data']['password'], sslmode='disable')
    except:
        raise RuntimeError("I am unable to connect to the database")

    # Add data to DB if there is POSTDATA found
    if request.form:
        ins_cur = conn.cursor()
        ins_cur.execute(
            """INSERT INTO staff (LastName, FirstName, Company) VALUES (%(last_name)s, %(first_name)s, %(company)s);""", request.form
        )
        conn.commit()
        ins_cur.close()

    sel_cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
    sel_cur.execute('SELECT * from staff;')
    rows = [dict(row) for row in sel_cur.fetchall()]
    sel_cur.close()

    template_params = {
        'creds_expiry': time.strftime("%Z - %Y/%m/%d, %H:%M:%S", time.localtime(cache.get('db_creds_expiry'))),
        'result': json.dumps(result, indent=2),
        'db_result': rows
    }
    return render_template('index.html', **template_params)

@app.route('/bulma.css')
def send_js(path):
    return send_file('static/bulma.css')

if __name__ == "__main__":
    app.run(host='0.0.0.0', debug=True)
