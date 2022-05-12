import time
import string
import random
import sys
from requests import get, post, delete, put


def test_get_index():
    print("[Checking if SOCA Web API is alive]")
    req = get(FLASK_ENDPOINT, headers={}, params={})
    print(" >> {}".format(req.status_code))
    assert req.status_code == 200


def test_create_user_no_sudo():
    print("[Creating regular user: " + USERNAME + " and password " + PASSWORD + "]")
    req = post(FLASK_ENDPOINT + "/api/ldap/user",
                headers={"X-SOCA-TOKEN": X_SOCA_TOKEN,
                        "X-SOCA-USER": X_SOCA_USER},
               data={"user": USERNAME,
                     "password": PASSWORD,
                     "email": "test@fakepath.net",
                     "sudoers": False})
    print(" >> {}: {}".format(req.status_code, req.json()))
    assert req.status_code == 200


def test_authenticate():
    print("[Try to authenticate with user: " + USERNAME + "]" )
    req = post(FLASK_ENDPOINT + "/api/ldap/authenticate",
                data={"user": USERNAME,
                     "password": PASSWORD})
    print(" >> {}: {}".format(req.status_code, req.json()))
    assert req.status_code == 200


def test_retrieve_user():
    print("[Retrieving LDAP information for user : " + USERNAME + "]")
    req = get(FLASK_ENDPOINT + "/api/ldap/user",
                headers={"X-SOCA-TOKEN": X_SOCA_TOKEN,
                         "X-SOCA-USER": X_SOCA_USER},
                params={"user": USERNAME})
    print(" >> {}: {}".format(req.status_code, req.json()))
    assert req.status_code == 200

def test_retrieve_user_api_key():
    print("[Retrieving API key  for user : " + USERNAME + "]")
    req = get(FLASK_ENDPOINT + "/api/user/api_key",
              headers={"X-SOCA-TOKEN": X_SOCA_TOKEN,
                       "X-SOCA-USER": X_SOCA_USER},
              params={"user": USERNAME})
    global temp_user_api_key
    temp_user_api_key = req.json()["message"]
    print(" >> {}: {}".format(req.status_code, req.json()))
    assert req.status_code == 200


def test_retrieve_user_no_permission():
    print("[Trying to query LDAP permission from which user don't have access]")
    req = get(FLASK_ENDPOINT + "/api/ldap/user",
              headers={"X-SOCA-TOKEN": temp_user_api_key,
                       "X-SOCA-USER": USERNAME},
              params={"user": X_SOCA_USER})
    print(" >> {}: {}".format(req.status_code, req.json()))
    assert req.status_code == 401

    # get user
    #http://127.0.0.1:5000/api/ldap/user?user=mickael
    # change password

    # verify initial password does not work

    # verify new password is ok


if __name__ == '__main__':
    USERNAME = ''.join(random.choice(string.ascii_lowercase) for i in range(10))
    PASSWORD = ''.join(random.choice(string.ascii_lowercase) for i in range(10))
    PASSWORD_AFTER_CHANGE = ''.join(random.choice(string.ascii_lowercase) for i in range(10))
    UID = random.randint(7000, 8000)
    GID = random.randint(8001, 9000)

    # Change setting as needed
    # Choose User/Token with SUDO permission
    FLASK_ENDPOINT = "http://localhost:5000"
    X_SOCA_TOKEN = "096c3bdd7a3178898f8d91398b870597"
    X_SOCA_USER = "mickael"

    test_get_index()
    test_create_user_no_sudo()
    test_authenticate()
    test_retrieve_user()
    test_retrieve_user_api_key()
    test_retrieve_user_no_permission()

    print("All test passed ... ! ")
