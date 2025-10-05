require_relative '../spec-helper'

require 'sg/ext'
using SG::Ext

require 'nonop/bit-field'

describe NonoP::BitField do
  bits = { A: 1, B: 2, C: 4, D: 8 }
  masks = { Value: 0xF }

  let(:bf) { described_class.new(bits, masks) }
  subject { bf }
  bits.each do |bit_name, bit_value|
    it { expect(subject.key_for(bit_value)).to eql(bit_name) }
    it { expect(subject.value_for(bit_name)).to eql(bit_value) }
    it { expect(subject.value_for(bit_name.to_s)).to eql(bit_value) }
  end
  it { expect(subject.A).to eql(1) }
  it { expect(subject[:A]).to eql(1) }
  it { expect(subject[1]).to eql(1) }
  it { expect(subject.Value).to eql(0xF) }
  it { expect(subject[:Value]).to eql(0xF) }
  
  describe 'zero' do
    subject { bf.new(0) }

    bits.each do |bit_name, bit_value|
      it { expect(subject.key_for(bit_value)).to eql(bit_name) }
      it { expect(subject.value_for(bit_name)).to eql(bit_value) }
      it { expect(subject.value_for(bit_name.to_s)).to eql(bit_value) }

      it { expect(subject & bit_name).to eql(false) }
      it { expect(subject & bit_name).to eql(false) }

      it { expect(subject | bit_name).to eql(bf.new(bit_value)) }
      it { expect(subject | bit_value).to eql(bf.new(bit_value)) }
    end

    it { expect(subject.value).to eql(0) }
    it { expect(subject.bits).to eql(bits) }
    it { expect(subject.to_a).to be_empty }
    it { expect(subject.to_s).to eql("%BitField[]") }
    it { expect(subject.to_i).to eql(0) }

    it { expect(subject & [ :A, :B ]).to be(false) }

    it { bits.each { |k,v|
        expect { subject.set!(k) }.
        to change { subject.value }.to eql(subject.value | v) } }
    it { bits.each { |k,v|
        expect { subject.set!(v) }.
        to change { subject.value }.to eql(subject.value | v) } }

    it { expect { subject.set(1) }.to_not change(subject, :value) }

    it { expect((~subject).value).to eql(~0) }

    it { expect(subject.eql?(0)).to be(true) }
    it { expect(subject == 0).to be(true) }
    it { expect(subject != 0).to be(false) }

    it { expect(subject.eql?(4)).to be(false) }
    it { expect(subject == 4).to be(false) }
    it { expect(subject != 4).to be(true) }
  end

  describe 'all bits' do
    subject { bf.new(~0) }

    it { expect(subject.value).to eql(~0) }
    it { expect(subject.bits).to eql(bits) }
    it { expect(subject.to_a).to eql([:A, :B, :C, :D]) }
    it { expect(subject.to_s).to eql("%BitField[A, B, C, D]") }
    it { expect(subject.to_i).to eql(~0) }

    bits.each do |bit_name, bit_value|
      it { expect(subject & bit_name).to eql(true) }
      it { expect(subject & bit_value).to eql(true) }
      it { expect { subject.clear!(bit_name) }.
        to change { subject.value }.to eql(subject.value & ~bit_value) }
      it { expect { subject.clear!(bit_value) }.
        to change { subject.value }.to eql(subject.value & ~bit_value) }
      it { expect(subject | bit_name). to eql(bf.new(subject.value | bit_value)) }
      it { expect(subject | bit_value). to eql(bf.new(subject.value | bit_value)) }
    end

    masks.each do |mask_name, mask_value|
      it { expect { subject.mask!(mask_value) }.
          to change { subject.value }.to eql(subject.value & mask_value) }
      it { expect { subject.mask!(mask_name) }.
          to change { subject.value }.to eql(subject.value & mask_value) }
    end

    it { expect(subject & [ :A, :B ]).to be(true) }
    it { expect { subject.clear(1) }.to_not change(subject, :value) }
    it { expect((~subject).value).to eql(0) }

    it { expect(subject.eql?(~0)).to be(true) }
    it { expect(subject == ~0).to be(true) }
    it { expect(subject != ~0).to be(false) }

    it { expect(subject.eql?(4)).to be(false) }
    it { expect(subject == 4).to be(false) }
    it { expect(subject != 4).to be(true) }
  end
end
