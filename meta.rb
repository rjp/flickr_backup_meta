require 'rubygems'
require 'flickraw'
require 'dbi'
require 'time'

# apikey, dsn, user

FlickRaw.api_key = ARGV[0]
dsn = ARGV[1]
user = ARGV[2]

$dbh = DBI.connect(dsn, '', '')
$dbh['AutoCommit'] = false

info = flickr.people.getInfo( :user_id => user )

base = 0
page = 1
pagesize = 500

# TODO add either table or columns to allow insertion of photo thumbnail
#   ie secret, farm, server 
# CREATE TABLE photo (id char(12) primary key, upload timestamp, got_exif timestamp, title varchar(1024), taken timestamp, last_update timestamp, ispublic int, isfriend int, isfamily int, latitude double, longitude double, media varchar(16), tags varchar(1024), views int);
# CREATE TABLE tag (id char(12), tag varchar(1024), namespace raw varchar(1024), predicate varchar(1024), value varchar(1024), primary key(id, tag));
# CREATE TABLE exif (id char(12), tag varchar(1024), value varchar(1024), raw varchar(1024), clean varchar(1024), primary key(id, tag));

last_photo = $dbh.select_one('select max(upload) from photo')
last_upload = last_photo[0].nil? ? 0 : Time.parse(last_photo[0]).to_i

if last_upload > 0 then
    puts "fetching since #{Time.at(last_upload)}"
end

# ignore primary key conflicts, we're guaranteed to get them
photos = $dbh.prepare("insert or ignore into photo values (?,?,NULL,?,?,?,?,?,?,?,?,?,?,?)")

# replace into the exif table, just in case something ever changes
insertexif = $dbh.prepare("insert or replace into exif values (?,?,?,?,?)")

# replace into the tag table, just in case something ever changes
inserttag = $dbh.prepare("insert or replace into tag values (?,?,?,?,?)")

loop do
    list = flickr.photos.search(
        :user_id => user,
        :per_page => pagesize,
        :page => page,
        :extras => 'date_upload,last_update,date_taken,geo,tags,media,views',
        :sort => 'date-posted-asc',
        :min_upload_date => last_upload
    )

    if list.size == 0 then
        break
    end

    # queue all the photos we've just got from flickr
    $dbh.transaction do
        list.each do |photo|
        # <photo id="4862693" owner="12708857@N00" secret="982c7066df"
        #  server="3" farm="1" title="Early sunrise" ispublic="1"
        #  isfriend="0" isfamily="0" dateupload="1108498665"/>

            photos.execute(
                photo.id,
                Time.at(photo.dateupload.to_i).iso8601,
                photo.title,
                photo.datetaken,
                Time.at(photo.lastupdate.to_i).iso8601,
                photo.ispublic,
                photo.isfriend,
                photo.isfamily,
                photo.latitude,
                photo.longitude,
                photo.media,
                photo.tags,
                photo.views
            )
        end
    end

    page = page + 1
end

#### find some photos that don't have their exif

pending_exif = $dbh.select_all('select id from photo where got_exif is null')

j=0
pending_exif.each do |id|
    exiftags = flickr.photos.getExif(:photo_id => id)

    cached = Hash.new { |h,k| h[k]=Array.new }

    # EXIF can have multiple values for the same tag name
    exiftags.exif.each do |tag|
        clean = tag.respond_to?('clean') ? tag.clean : nil
        cached[tag.label].push [tag.raw, clean]
    end

    $dbh.transaction do
        # clean up the EXIF as best we can
        cached.keys.each do |t|
            raw = cached[t].map{|i|i[0]}.compact.uniq.join(';;')
            clean = cached[t].map{|i|i[1]}.compact.uniq.join(';;')
            nc = clean

            # I like my Aperture to be f/x.y or f/x so clean this up
            if t == 'Aperture' then
                v = clean.gsub('f/','').to_f
                nc = sprintf((v > 9 ? 'f/%d' : 'f/%.1f'), v)
            end
            insertexif.execute(id, t, clean, raw, nc)
        end
        $dbh.do('update photo set got_exif=? where id=?', Time.now, id)
    end

    if j % 25 == 0 then
        print "."
        $stdout.flush
        sleep 2
    end
    j=j+1
end

#### bust open tags into the tag table 
# doesn't use Flickr, but we could if we wanted/needed raw not normalised

pending_tag = $dbh.select_all('select id from photo where (select count(id) from tag) = 0')

$dbh.transaction do
    pending_tag.each do |id|
        tags = $dbh.select_one('select tags from photo where id=?', id)
        taglist = tags[0].split(' ');
       
        taglist.each do |tag|
            m = tag.match('(\w+):(\w+)=(.+)')
            
            # this bit might be unRubyish
            if m:
                inserttag.execute(id, tag, m[1], m[2], m[3])
            else
                inserttag.execute(id, tag, nil, nil, nil)
            end
        end
    end
end
