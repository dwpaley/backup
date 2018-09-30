from googleapiclient.errors import HttpError
import sys
import pickle
import time

OWNER = 'dwp2111@columbia.edu'


def get_id(email):
    perms = service.files().list(
            pageSize=1, 
            q='"{}" in readers'.format(email), 
            fields='files/permissions'
            ).execute()['files'][0]['permissions']
    for p in perms:
        if p['emailAddress']==email:
            print('found id: {}'.format(p['id']))
            return p['id']

def callback(request_id, response, exception):
    if exception: 
        print(exception)
        #errors.append(exception)
    else: pass

def main():

    unshare_email = sys.argv[1]
    unshare_id = get_id(unshare_email)
    n_matches, n_prev = 0,0
    while True:
        try:
            time.sleep(1)
            print('find matches')
            matches = service.files().list(
                    pageSize=100, 
                    q='"{}" in readers and "{}" in owners'.format(
                        unshare_email,OWNER),
                    fields='files/id',
                    orderBy='createdTime'
                    ).execute()
        except googleapiclient.errors.HttpError as e:
            continue

        n_matches = len(matches['files'])
        print('{} matches'.format(n_matches))
        batch = service.new_batch_http_request(callback=callback)
        for f in matches['files']:
            batch.add(service.permissions().delete(
                fileId=f['id'],
                permissionId=unshare_id
                ))
        time.sleep(1)
        print('execute unshare')
        batch.execute()


if __name__=='__main__':
    main()
