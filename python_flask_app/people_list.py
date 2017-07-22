from flask import Flask, render_template, request
from werkzeug.contrib.cache import SimpleCache
import time
import hvac
import os
import json
import psycopg2
import psycopg2.extras
app = Flask(__name__)
cache = SimpleCache(default_timeout=60)

@app.route('/', methods=['GET', 'POST'])
def default_page():
    #############################
    # VAULT AUTH
    #############################
    client = hvac.Client(url=os.environ['VAULT_ADDR'], token=os.environ['VAULT_TOKEN'])

    if (not cache.get('db_creds_expiry')) or int(time.time()) > (cache.get('db_creds_expiry') - 10):
        db_creds = client.read('database/creds/people_list-readwrite')
        cache.set('db_creds_result', json.dumps(db_creds))
        cache.set('db_creds_expiry', int(time.time()+db_creds["lease_duration"]))
    else:
        db_creds = json.loads(cache.get('db_creds_result'))

    #############################
    # DB ACCESS/USAGE
    #############################
    conn = psycopg2.connect(dbname='people_list', user=db_creds['data']['username'], host='postgresql', password=db_creds['data']['password'], sslmode='disable')

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

    #############################
    # TEMPLATE RENDERING
    #############################
    template_params = {
        'creds_expiry': time.strftime("%Z - %Y/%m/%d, %H:%M:%S", time.localtime(cache.get('db_creds_expiry'))),
        'db_creds': json.dumps(db_creds, indent=2),
        'db_result': rows
    }
    return render_template('index.html', **template_params)

@app.route('/bulma.css')
def send_js(path):
    return send_file('static/bulma.css')

if __name__ == "__main__":
    app.run(host='0.0.0.0', debug=True)
