def attach? export, user: nil, uid: nil, **opts
  ((user == ENV['USER'] || uid == Process.uid) ||
   (export == 'ctl' && (user == 'root' || uid == 0))).tap do |r|
    NonoP.vputs {
      "Access export? %s/%s %s/%s %s => %s" %
      [ user.inspect, ENV['USER'].inspect, uid.inspect, Process.uid, export.inspect, r.inspect ]
    }
  end
end
