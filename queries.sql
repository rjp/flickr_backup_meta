interesting queries

# media split
select media, count(1) as count from photo group by media;

# makes/models by count
select count(1) as count, tag.tag as make from photo, tag where photo.id=tag.id and tag.namespace='camera' and tag.predicate='make' group by tag.tag order by count desc;
select count(1) as count, tag.tag as model from photo, tag where photo.id=tag.id and tag.namespace='camera' and tag.predicate='model' group by tag.tag order by count desc;

# top tags (excluding machine tags)
select count(1) as count, tag from tag where namespace is null group by tag order by count desc limit 25;

# views
select id, views, upload, taken from photo order by views desc limit 25; 
# fastest views - this is going to be biased towards new things
select id, views, views*60*60*24/(strftime('%s', 'now')-strftime('%s', upload)) as speed from photo order by speed desc limit 25;
