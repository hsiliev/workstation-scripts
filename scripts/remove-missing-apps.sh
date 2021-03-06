#!/usr/bin/env bash
set -e

echo "Checking if logged with admin user ..."
cf target | grep user | grep admin

# Generated by service-tunnel.sh
CONNECTION="mongodb://d4d0f7aa4ea7cfc90ebb017a4d453b4d:0efd3d2d3ce4c63220e67520dd398663@localhost:27020/072700544269b377"
MONTH=04

echo "Trying to obtain data for month $MONTH with connection to $CONNECTION"
EVAL_SCRIPT="db.getCollectionNames().forEach(function(collectionName) {
    if ( collectionName.match(/abacus-carry-over.*2018$MONTH/) ) {
      db.getCollection(collectionName).find({state: 'STARTED'}, { _id: 1 }).forEach(function(doc) {
        // extract app guid from document id
        print(doc._id.match(/app:([0-f|-]+)/)[1]);
      });
    }
})"
GUIDS=($(mongo "$CONNECTION" --quiet --eval "$EVAL_SCRIPT"))
echo "DB contains ${#GUIDS[@]} started apps"

for GUID in "${GUIDS[@]}"; do
  OUTPUT=$(cf curl /v2/apps/$GUID/summary)
  if [[ $OUTPUT =~ .*AppNotFound.* ]]; then
    echo "Deleting missing app guid $GUID : $OUTPUT :"
    EVAL_SCRIPT="db.getCollectionNames().forEach(function(collectionName) {
       if ( collectionName.match(/abacus-carry-over.*2018$MONTH/) ) {
         const result = db.getCollection(collectionName).remove({_id: /app:$GUID/, state: 'STARTED'});
         print('   ' + collectionName + ' ' + result);
       }
    })"
    mongo "$CONNECTION" --quiet --eval "$EVAL_SCRIPT"
  else
    echo -en "Found app with guid $GUID\r"
  fi
done

echo "Done.                                                   "
