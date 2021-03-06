; Kin's GitHub Feed for ReaperCon
; irc.GeekShed.net #ReaperCon

; ---- USAGE:
; !github https://github.com/Th3GrimRipp3r/ReaperCon/blob/master/Bot%20Scripts/Kin-Socket-ReaperCon-Feed.mrc
; !github Th3GrimRipp3r/ReaperCon
; !reapercon
; /ReaperConFeed.Get GitHubUser/RepositoryName !msg #Channel Text To Display Before Feed Result
; /ReaperConFeed.Get GitHubUser/RepositoryName echo -ag

; ---- History:
; 2014-01-27 v1.8 Added !github trigger, and rearranged alias, to report the last commit from any github repository
; 2013-01-25 v1.7 Use Author name if available, URI if not, or email as a last resort
; 2013-03-26 v1.6 Report the first file modified/added/removed for each commit
; 2013-03-13 v1.5 Few touch-ups, improved HTTP headers
; 2013-03-12 v1.4 Sneakily extract the extended description from commit feed's <content> tag
; 2013-03-12 v1.3 Minor fixes
; 2013-03-12 v1.2 HTML Entity handling
; 2013-03-12 v1.1 Added channel trigger and polling timer
; 2013-03-12 v1.0

; -------- Configuration

alias -l MaxMessageLength { return 384 }

; -------- Automatic Feed Timer

on *:CONNECT:{ if ($network == GeekShed) { ReaperConFeed.Enable } }
on *:DISCONNECT:{ if ($network == GeekShed) { ReaperConFeed.Disable } }
alias ReaperConFeed.Enable { .timerReaperConFeed.Check 0 120 ReaperConFeed.Check }
alias ReaperConFeed.Disable { .timerReaperConFeed.Check off }
alias -l ReaperConFeed.Check { if ($me ison #ReaperCon) { ReaperConFeed.Get Th3GrimRipp3r/ReaperCon !msg #ReaperCon $ReaperConTag } }

; -------- Events

on *:TEXT:!*:#ReaperCon:{
  if ($nick !isop $chan) && ($nick !ishop $chan) { return }
  if (!$istok(!ReaperCon !TomHub !GitHub,$1,32)) { return }
  var %feedpath
  var %msgtag
  if ($1 == !ReaperCon) { %feedpath = Th3GrimRipp3r/ReaperCon | %msgtag = $ReaperConTag }
  if ($1 == !TomHub) { %feedpath = TomCoyote/Cindy | %msgtag = $GitHubTag(Cindy) }
  if ($2) && ($regex(githubpath,$2,/^(?:https?:\/\/)?(?:www\.)?(?:github\.com)?\/?([^\/]++\/([^\/]++))/)) { %feedpath = $regml(githubpath,1) | %msgtag = $GitHubTag($regml(githubpath,2)) }
  if (!%feedpath) {
    !msg $chan $GitHubTag(GitHub) Error - Please use the format !GitHub GitHubUserName/RepositoryName
    return
  }
  unset %ReaperConFeed.Last. [ $+ [ %feedpath ] ]
  ReaperConFeed.Get %feedpath !msg $chan %msgtag
}

; -------- Socket

alias ReaperConFeed.Get {
  ReaperConFeed.Timeout 

  if ($1) && (!$regex(validatepath,$1,/^([^\/]++\/([^\/]++))/)) { return }

  var %callback $2-
  if (!%callback) || (!$istok(say msg echo notice describe,$replace($gettok(%callback,1,32),!,),32)) { %callback = !echo -ta $GitHubTag(GitHub) }

  if $hget(ReaperConFeed) { hfree ReaperConFeed }
  hadd -m ReaperConFeed Host github.com
  hadd ReaperConFeed FeedPath $1
  hadd ReaperConFeed Path / $+ $1 $+ /commits/master.atom
  hadd ReaperConFeed Callback %callback
  hadd ReaperConFeed File $qt($mIRCdir $+ ReaperConFeed. $+ $ctime $+ .dat)

  .timerReaperConFeed 1 12 ReaperConFeed.Timeout 
  sockopen -e ReaperConFeed github.com 443
}

alias -l ReaperConFeed.Timeout {
  if ($sock(ReaperConFeed)) .sockclose ReaperConFeed
  if $hget(ReaperConFeed) { 
    var %file $hget(ReaperConFeed,File)
    if ($exists(%file)) { .remove %file }
  }
  if $hget(ReaperConFeed) { hfree ReaperConFeed }
  .timerReaperConFeed off
}

on *:SOCKOPEN:ReaperConFeed: {
  var %host $hget(ReaperConFeed,Host), %path $hget(ReaperConFeed,Path)

  sockwrite -nt $sockname GET %path HTTP/1.1
  sockwrite -nt $sockname HOST: %host

  sockwrite -nt $sockname Accept-Encoding: 
  sockwrite -nt $sockname Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
  sockwrite -nt $sockname Connection: close

  sockwrite -nt $sockname $crlf
}
on *:SOCKREAD:ReaperConFeed: {
  var %callback $hget(ReaperConFeed,Callback)
  var %file $hget(ReaperConFeed,File)

  if ($sockerr) { !echo -tsg 04Socket Error in SOCKREAD - $sock($sockname).wserr -  $sock($sockname).wsmsg | .sockclose $sockname | halt }

  while ($sock($sockname).rq) {
    ; sockread -fn $sock($sockname).rq &br
    sockread -f $sock($sockname).rq &br
    bwrite %file -1 -1 &br
  }
  bunset &br
}
on *:SOCKCLOSE:ReaperConFeed: { ReaperConFeed.Close }

alias -l ReaperConFeed.Close {
  .timerReaperConFeed off

  var %callback $hget(ReaperConFeed,Callback)
  var %feedpath $hget(ReaperConFeed,FeedPath)

  var %id 1
  if ($ReaperConFeed.Parse(%callback,$hget(ReaperConFeed,File),%id) == $true) {
    var %out
    var %link

    %out = %out $Colorize(05,$Hash.GetData(%id,Name))
    if ($Hash.GetData(%id,Action)) && ($Hash.GetData(%id,Script)) {
      %out = %out $Hash.GetData(%id,Action) 
      %out = %out $Colorize(06,$Hash.GetData(%id,Script))
    }
    %out = %out -> $Colorize(07,$left($Hash.GetData(%id,Title),208)) <-

    %link = %link $iif($Hash.GetData(%id,Updated),$+($chr(91),$v1,$chr(93)))
    %link = %link $iif($Hash.GetData(%id,Link),$left($v1,120))

    ; Try to sneak the extended description from the commit into the output
    if ($Hash.GetData(%id,Extended)) && ($len($Hash.GetData(%id,Extended)) > 5) {
      var %max $calc($MaxMessageLength - ($len(%out) + $len(%link)))
      if (%max > 5) {
        %out = %out $Colorize(03,$left($Hash.GetData(%id,Extended),%max))
      }
    }

    %out = %out %link

    if (%callback) && (($var($+(ReaperConFeed.Last.,%feedpath),0) == 0) || (%out != $var($+(ReaperConFeed.Last.,%feedpath),1).value)) {
      %callback %out
      set %ReaperConFeed.Last. $+ %feedpath %out
    }
  }

  ReaperConFeed.Timeout 
}

alias ReaperConFeed.Parse {
  var %callback $1, %file $2, %id $gettok($3,1,32), %bfound $null

  ; var %data $Kin.Parser.Find(%file,<entry>,</entry>)
  var %data $Kin.Parser.Find(%file,<entry>,<content)

  if ($regex(%data,/<link [^>]*? href="([^"]+)/)) { noop $Hash.SetData(%id,Link,$regml(1)) }
  if ($regex(%data,/<title>([^<]*)<\/title>/)) { noop $Hash.SetData(%id,Title,$regml(1)) }
  if ($regex(%data,/<updated>([^<]*)<\/updated>/)) { noop $Hash.SetData(%id,Updated,$regml(1)) }
  if ($regex(%data,/<name>([^<]+)<\/name>/)) { noop $Hash.SetData(%id,Name,$regml(1)) | %bfound = $true }
  if (!%bfound) {
    if ($regex(%data,/<uri>([^<]+)<\/uri>/)) { noop $Hash.SetData(%id,Name,$regml(1)) | %bfound = $true }
  }
  if (!%bfound) {
    if ($regex(%data,/<email>([^<]+)<\/email>/)) {
      if (TheReaper isin $regml(1)) {
        noop $Hash.SetData(%id,Name,"Dan Reaper")
      }
      else {
        noop $Hash.SetData(%id,Name,$regml(1)) 
      }
      %bfound = $true
    }
  }

  ; Extended description inside <content ..> ?
  var %content $Kin.Parser.Find(%file,> $+ $Hash.GetData(%id,Title),</content>)
  if ($regex(%content,/(.*)&lt;\/pre>/)) { noop $Hash.SetData(%id,Extended,$remove($regml(1),> $+ $Hash.GetData(%id,Title))) }

  ; Find the first file modified
  var %contentext $Kin.Parser.Find(%file,</author>,</content>)
  if ($regex(%contentext,/<content type="html">\s+?&lt;pre>([m+-]) +(\S+.*?)(?=\s+[m+-]\s+|\s*&lt;/pre>)/)) {
    noop $Hash.SetData(%id,Action,$replace($regml(1),m,modified,+,added,-,removed))
    noop $Hash.SetData(%id,Script,$regml(2))
  }

  return %bfound
}

;-------- 

alias Colorize { return $iif($regex(color,$1,/^(0?\d|1[01-5])$/),$+($chr(03),$1,$$2-,$chr(03),$chr(15)),$1-) }
alias ReaperConTag { return $+($chr(40),$Colorize(06,ReaperCon),$chr(41)) }
alias GitHubTag { return $+($chr(40),$Colorize(06,$1-),$chr(41)) }

alias -l Hash.GetData { return $hget(ReaperConFeed,$+(Entry.,$1,.,$$2)) }
alias -l Hash.SetData { hadd ReaperConFeed $+(Entry.,$1,.,$$2) $HTMLEntities($3-) }

;-------- Helper Aliases

; 2012-12-01 v1.0 Kin's Binary Data File Parser Find Alias
alias -l Kin.Parser.Find {
  var %replaceascii 0 9 10 13

  var %file $1
  var %starttext $2
  var %stoptext $3
  if (!$exists(%file)) { return $null }
  bread %file 0 $file(%file).size &br

  var %start $bfind(&br,0,%starttext)
  if (%start == $null) || (%start <= 0) { return $null }

  var %stop $bfind(&br,%start,%stoptext)
  inc %stop $len(%stoptext)
  if (%stop == $null) || (%stop <= 0) { return $null }

  var %each $numtok(%replaceascii,32)
  while (%each) {
    var %char $gettok(%replaceascii,%each,32)
    var %ix $bfind(&br,%start,%char)
    while (%ix <= %stop) && (%ix > 0) {
      bset &br %ix 32
      var %ix $bfind(&br,%start,%char)
    }
    dec %each
  }

  var %output $bvar(&br,%start,$calc(%stop - %start)).text

  bunset &br
  return %output
}

alias -l HTMLEntities {
  ; Handle possible double-encoded &amp;s before anything else
  var %ent $replace($1-,&#038;,$chr(38),&#38;,$chr(38))
  ; Common named entities
  %ent = $replace(%ent,&quot;,$chr(34),&amp;,$chr(38),&lt;,$chr(60),&gt;,$chr(62),&nbsp;,$chr(160))
  %ent = $replace(%ent,&pound;,$chr(163),&copy;,$chr(169),&reg;,$chr(174),&deg;,$chr(176),&plusmn;,$chr(177),&sup2;,$chr(178),&sup3;,$chr(179),&divide;,$chr(247),&#8217;,')
  ; Global replace on remaining numerics
  %ent = $regsubex(HTMLEntities,%ent,/&#(\d+);/g,$chr(\1))
  return %ent
}
