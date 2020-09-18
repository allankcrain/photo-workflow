#!/bin/bash

PIX=/mnt/pictures/allanc/Pictures
PBK=/mnt/pictures-bak/allanc/Pictures
# Check to make sure that both the Pictures and Pictures-bak raids are mounted
if [ -f $PIX/raid-sanity-main ]; then
  if [ -f $PBK/raid-sanity-backup ]; then
    echo "Last backup attempt: "`date` >$PIX/raid-sanity-main
    rsync -a --delete-after /mnt/pictures/ /mnt/pictures-bak/
    mv $PBK/raid-sanity-main $PBK/raid-sanity-backup
  else
    echo "Dang, backup Pictures RAID isn't mounted?"
  fi
else
  echo "Dang, main Pictures RAID isn't mounted?"
fi
