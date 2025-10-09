def auth? export: nil, user: nil, **opts
  ((user&.name == ENV['USER'] || user&.uid == Process.uid) ||
   ((export.empty? || export == 'ctl') &&
    (user&.name == 'root' || user&.uid == 0))).tap do |r|
    NonoP.vputs {
      "Access export? %s %s/%s %s/%s %s => %s" %
      [ user.class, user.inspect, ENV['USER'].inspect, user&.uid.inspect, Process.uid, export.inspect, r.inspect ]
    }
  end
end

def attach?(export, **o)
  auth?(**o.merge(export:))
end

def attach_as?(export, user:, as:, **o)
  attach?(export, **o.merge(user:)) && (as == user || user.name == 'root')
end
