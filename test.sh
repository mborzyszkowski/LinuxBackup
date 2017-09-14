./linuxbackup.sh \
   --name='nazwa_pliku' \
   --full-interval='*/5 * * * *' \
   --inc-interval='*/1 * * * *' \
   --path='test/files' \
   --gzip \
   --ext='txt,jpg,cpp' \
   --backup_dir='test/backup' \
   --remove
