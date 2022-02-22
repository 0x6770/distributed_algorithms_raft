#!/bin/bash

databases=./database/*
num_databases=$(ls ${databases} | wc -l)
hashes=()

for database in ${databases}; do
  hash=$(md5sum "${database}")
  echo "${hash}"
  hash=$(echo "${hash}"| awk '{ printf $1 }')
  hashes+=(${hash})
done

for hash in "${hashes[@]}"; do
  if [ "${hash}" ==  "${hashes[0]}" ]
  then
    ((all_the_same=all_the_same+1))
  fi
done

max_num_same=$(echo "${hashes[@]}" \
                | tr " " "\n" \
                | sort \
                | uniq -c \
                | sort -k2nr \
                | awk 'END{print}' \
                | awk '{printf $1}'
              )

if [ "${max_num_same}" == "${num_databases}" ]
then
  echo "All ${max_num_same} databases are the same."
  exit 0
fi

echo "At most ${max_num_same} out of ${num_databases} databases are consistent."
exit 1
