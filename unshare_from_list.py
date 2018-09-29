'''Modified to use service account, but not sure if it's working again after
the changes
'''
from googleapiclient.discovery import build
from httplib2 import Http
from oauth2client import file, client, tools
from oauth2client.tools import argparser
import pickle
import time
import re

SERVICE_ACCOUNT_FILE = 'dan-drivetest1-2f1b7bd0e7ac.json'
SCOPES = 'https://www.googleapis.com/auth/drive'
UNSHARE_FILE='dwpaley@gmail.com.no.txt'
UNSHARE_ID='16312335538820483178'
ID_FILE='paths_ids.p'


search_fileId = re.compile(r'files/([^/]+)/')
unshare_id_queue = []


def callback(request_id, response, exception):
    if exception:
        print(exception)
        unshare_id_queue.append(fileId_from_exception(exception))
    else:
        print('success')

def fileId_from_exception(exception):
    return search_fileId.search(exception.uri).groups()[0]

def build_service():
    credentials = service_account.Credentials.from_service_account_file(
            SERVICE_ACCOUNT_FILE, scopes=SCOPES)
    return build('drive', 'v3', credentials=credentials)

def main():
    service = build_service()
    with open(UNSHARE_FILE) as f: 
        unshare_lines = [l.strip() for l in f.readlines()]
    with open(ID_FILE, 'rb') as f: 
        paths_ids = pickle.load(f)
    unshare_id_queue += [paths_ids[l] for l in unshare_lines]
    batch,batch_count = service.new_batch_http_request(callback=callback),0
    while unshare_id_queue:
        if batch_count==10:
            time.sleep(1)
            print('executing: {} in queue'.format(len(unshare_id_queue)))
            batch.execute()
            batch = service.new_batch_http_request(callback=callback)
            batch_count = 0
        id=unshare_id_queue.pop(0)
        batch.add(service.permissions().delete(
            fileId=id,
            permissionId=UNSHARE_ID
            ))
        batch_count += 1
    if batch_count: batch.execute()

if __name__=='__main__':
    main()

