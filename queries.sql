interesting queries

# media split
select media, count(1) as count from photo group by media;

## TAGS
# makes/models by count
select count(1) as count, tag.tag as make from photo, tag where photo.id=tag.id and tag.namespace='camera' and tag.predicate='make' group by tag.tag order by count desc;
select count(1) as count, tag.tag as model from photo, tag where photo.id=tag.id and tag.namespace='camera' and tag.predicate='model' group by tag.tag order by count desc;

# top tags (excluding machine tags)
select count(1) as count, tag from tag where namespace is null group by tag order by count desc limit 25;

## EXIF
# makes/model by count
select count(1) as count, a.raw as make, b.raw as model from exif a, exif b on a.id=b.id where a.tag='Make' and b.tag='Model' group by make, model order by count desc;
select count(1) as count, a.raw as make from exif a where a.tag='Make' group by make order by count desc;
select count(1) as count, a.raw as model from exif a where a.tag='Model' group by model order by count desc;

# views
select id, views, upload, taken from photo order by views desc limit 25; 
# fastest views - this is going to be biased towards new things
select id, views, views*60*60*24/(strftime('%s', 'now')-strftime('%s', upload)) as speed from photo order by speed desc limit 25;

# which photos have tags or exif, NULL=absent
select p.id, nullif(exists (select id from tag where id=p.id limit 1), 0) as has_tags, nullif(exists (select id from exif where id=p.id limit 1), 0) as has_exif from photo p; 
