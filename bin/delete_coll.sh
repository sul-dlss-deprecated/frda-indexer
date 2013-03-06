# change value below 
# this will delete all documents indicated by the query
curl "https://sul-solr-test.stanford.edu/solr/frda/update?commit=true" -H "Content-Type: application/xml" --data-binary '<delete><query>collection_ssi:Imagesqqq*</query></delete>'
