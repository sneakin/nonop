def auth? export: nil, user: nil, uid: nil, **opts
  ((user == ENV['USER'] || uid == Process.uid) ||
   ((export.empty? || export == 'ctl') &&
    (user == 'root' || uid == 0))).tap do |r|
    NonoP.vputs {
      "Access export? %s %s/%s %s/%s %s => %s" %
      [ user.class, user.inspect, ENV['USER'].inspect, uid.inspect, Process.uid, export.inspect, r.inspect ]
    }
  end
end

def attach?(export, **o)
  auth?(**o.merge(export:))
end
