require 'ninep'

module NineP::TestData
  EXCHANGE1 = <<-EOT
> 2025/09/10 18:17:34.000106498  length=21 from=0 to=20
 15 00 00 00 64 ff ff 00 00 01 00 08 00 39 50 32 30 30 30 2e 4c
< 2025/09/10 18:17:34.000106799  length=21 from=0 to=20
 15 00 00 00 65 ff ff 00 00 01 00 08 00 39 50 32 30 30 30 2e 4c
> 2025/09/10 18:17:34.000106963  length=38 from=21 to=58
 26 00 00 00 66 00 00 00 00 00 00 00 00 13 00 2f 68 6f 6d 65 2f 6d 6f 62 69 6c 65 2f 50 75 62 6c 69 63 e8 03 00 00
< 2025/09/10 18:17:34.000107307  length=20 from=21 to=40
 14 00 00 00 67 00 00 08 00 00 00 00 00 00 00 00 00 00 00 00
> 2025/09/10 18:17:34.000107459  length=11 from=59 to=69
 0b 00 00 00 78 00 00 00 00 00 00
< 2025/09/10 18:17:34.000107647  length=7 from=41 to=47
 07 00 00 00 79 00 00
EOT
  EXCHANGE2 = EXCHANGE1.split("\n").each_slice(2).collect do |(a, b)|
    data = b.split.collect { _1.to_i(16) }.pack('C*')
    am = a.match(/([<>])\s+(\d+\/\d+\/\d+)\s+(\d+:\d+:\d+\.\d+)\s+length=(\d+)\s+from=(\d+)\s+to=(\d+)/)
    [ am[1], am[4].to_i, data ]
  end
  puts(EXCHANGE1)
  puts(EXCHANGE2.inspect)
end

describe NineP::Decoder do
  let(:client_data) { NineP::TestData::EXCHANGE2.select { _1[0] == '>' }.collect { _1[2] }.join }
  let(:server_data) { NineP::TestData::EXCHANGE2.select { _1[0] == '<' }.collect { _1[2] }.join }

  subject { described_class.new(coders: NineP::Decoder::RequestReplies.flatten.reject(&:nil?)) }

  it 'decodes all the client data' do
    $stderr.puts("client")
    more = client_data
    begin
      pkt, more = subject.unpack(more)
      $stderr.puts(pkt.inspect, more.inspect)
      expect(pkt).to be_kind_of(NineP::Packet)
      expect(more).to_not eql(nil)
    end while !more&.empty?
    expect(more).to eql("")
  end
    
  it 'decodes all the server data' do
    $stderr.puts("server")
    more = server_data
    begin
      pkt, more = subject.unpack(more)
      $stderr.puts(pkt.inspect, more.inspect)
      expect(pkt).to be_kind_of(NineP::Packet)
      expect(more).to_not eql(nil)
    end while !more&.empty?
    expect(more).to eql("")
  end
    
  NineP::TestData::EXCHANGE2.each do |(dir, length, data)|
    it "decodes the test data: #{data.inspect}" do
      pkt, more = subject.unpack(data)
      $stderr.puts(pkt.inspect, more.inspect, "")
      expect(more).to eql("")
      expect(pkt).to be_kind_of(SG::PackedStruct)
      expect(pkt.bytesize).to eql(length)
      expect(pkt.size).to eql(length)
      expect(pkt.type).to_not eql(0)
      expect(pkt.tag).to_not eql(nil)
      expect(pkt.raw_data).to eql(data[7..-1])
    end
    
    it 'rencodes to the test data' do
      pkt, more = subject.unpack(data)
      expect(pkt.pack).to eql(data)
    end
  end
end

describe NineP::L2000::Decoder do
  let(:client_data) { NineP::TestData::EXCHANGE2.select { _1[0] == '>' }.collect { _1[2] }.join }
  let(:server_data) { NineP::TestData::EXCHANGE2.select { _1[0] == '<' }.collect { _1[2] }.join }

  it 'handles Tauth' do
    expect(subject.packet_types[NineP::Tauth::ID]).to_not be(NineP::Tauth)
    expect(subject.packet_types[NineP::Tauth::ID]).to be(NineP::L2000::Tauth)
  end
  
  it 'decodes all the client data' do
    $stderr.puts("client")
    more = client_data
    begin
      pkt, more = subject.unpack(more)
      $stderr.puts(pkt.inspect, pkt.data.inspect, more.inspect)
      expect(pkt).to be_kind_of(SG::PackedStruct)
      expect(more).to_not eql(nil)
      expect(pkt.data).to be_kind_of(SG::PackedStruct)
      expect(pkt.data).to be_kind_of(NineP::Packet::Data)
      expect(pkt.extra_data).to eql("")
    end while !more&.empty?
    expect(more).to eql("")
  end
    
  it 'decodes all the server data' do
    $stderr.puts("server")
    more = server_data
    begin
      pkt, more = subject.unpack(more)
      $stderr.puts(pkt.inspect, pkt.data.inspect, more.inspect)
      expect(pkt).to be_kind_of(SG::PackedStruct)
      expect(more).to_not eql(nil)
      expect(pkt.data).to be_kind_of(SG::PackedStruct)
      expect(pkt.data).to be_kind_of(NineP::Packet::Data)
      expect(pkt.extra_data).to eql("")
    end while !more&.empty?
    expect(more).to eql("")
  end

  NineP::TestData::EXCHANGE2.each do |(dir, length, data)|
    it "decodes the test data: #{data.inspect}" do
      pkt, more = subject.unpack(data)
      $stderr.puts(pkt.inspect, more.inspect, "")
      expect(pkt).to be_kind_of(SG::PackedStruct)
      expect(more).to eql("")
      expect(pkt.data).to be_kind_of(SG::PackedStruct)
      expect(pkt.data).to be_kind_of(NineP::Packet::Data)
      expect(pkt.extra_data).to eql("")
    end
  end
end
