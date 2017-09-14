linuxbackup.sh \
   --name='back' \
   --full-interval='*/5 * * * *' \
   --inc-interval='*/1 * * * *' \
   --path='test/files' \
   --gzip \
   --ext='txt,jpg,cpp' \
   --backup-dir='test/backup' \
   --remove
