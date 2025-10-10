# -*- coding: utf-8 -*-
fs = NonoP::Server::HashFileSystem.
  new(name,
      umask: default_umask,
      entries: {
        'abcd' => "1234\n",
        "utf8.txt" => "😻\n".freeze
      })

fs

