# encoding: utf-8

require 'spec_helper'

describe Promise do
  subject { Promise.new }

  let(:value) { double('value') }
  let(:other_value) { double('other_value') }

  let(:backtrace) { caller }
  let(:reason) do
    StandardError.new('reason').tap { |ex| ex.set_backtrace(backtrace) }
  end
  let(:other_reason) do
    StandardError.new('other_reason').tap { |ex| ex.set_backtrace(backtrace) }
  end

  describe '3.1.1 pending' do
    it 'transitions to fulfilled' do
      subject.fulfill(value)
      expect(subject).to be_fulfilled
    end

    it 'transitions to rejected' do
      subject.reject(reason)
      expect(subject).to be_rejected
    end
  end

  describe '3.1.2 fulfilled' do
    it 'does not transition to other states' do
      subject.fulfill(value)
      subject.reject(reason)
      expect(subject).to be_fulfilled
    end

    it 'has a value' do
      subject.fulfill(value)
      expect(subject.value).to eq(value)

      subject.fulfill(other_value)
      expect(subject.value).to eq(value)
    end

    it 'freezes the value' do
      skip 'Dropped in 74da6e9'
    end
  end

  describe '3.1.3 rejected' do
    it 'does not transition to other states' do
      subject.reject(reason)
      subject.fulfill(value)
      expect(subject).to be_rejected
    end

    it 'has a reason' do
      subject.reject(reason)
      expect(subject.reason).to eq(reason)

      subject.reject(other_reason)
      expect(subject.reason).to eq(reason)
    end

    it 'freezes the reason' do
      skip 'Dropped in 74da6e9'
    end
  end

  describe '3.2.1 on_fulfill' do
    it 'is optional' do
      subject.then
      subject.fulfill(value)
    end
  end

  describe '3.2.1 on_reject' do
    it 'is optional' do
      subject.then(proc { |_| })
      subject.reject(reason)
    end
  end

  describe '3.2.2 on_fulfill' do
    it 'is called after promise is fulfilled' do
      fulfilled = nil
      subject.then(proc { |_| fulfilled = subject.fulfilled? })

      subject.fulfill(value)
      expect(fulfilled).to eq(true)
    end

    it 'is called with fulfillment value' do
      result = nil
      subject.then(proc { |val| result = val })

      subject.fulfill(value)
      expect(result).to eq(value)
    end

    it 'is called not more than once' do
      called = 0
      subject.then(proc { |_| called += 1 })

      subject.fulfill(value)
      subject.fulfill(value)
      expect(called).to eq(1)
    end

    it 'is not called if on_reject has been called' do
      called = false
      subject.then(proc { |_| called = true })

      subject.reject(reason)
      expect(called).to eq(false)
    end

    it 'can be passed as a block' do
      result = nil
      subject.then { |val| result = val }

      subject.fulfill(value)
      expect(result).to eq(value)
    end

    it 'takes precedence over block' do
      result = nil
      subject.then(proc { |_| result = :arg }) { |_| result = :block }

      subject.fulfill(value)
      expect(result).to be(:arg)
    end
  end

  describe '3.2.3 on_reject' do
    it 'is called after promise is rejected' do
      rejected = nil
      subject.then(nil, proc { |_| rejected = subject.rejected? })

      subject.reject(reason)
      expect(rejected).to eq(true)
    end

    it 'is called with rejection reason' do
      result = nil
      subject.then(nil, proc { |reas| result = reas })

      subject.reject(reason)
      expect(result).to eq(reason)
    end

    it 'is called not more than once' do
      called = 0
      subject.then(nil, proc { |_| called += 1 })

      subject.reject(reason)
      subject.reject(reason)
      expect(called).to eq(1)
    end

    it 'is not called if on_fulfill has been called' do
      called = false
      subject.then(nil, proc { |_| called = true })

      subject.fulfill(value)
      expect(called).to eq(false)
    end
  end

  describe '3.2.4' do
    it 'returns before on_fulfill or on_reject is called' do
      skip 'To be implemented by application code'
    end
  end

  describe '3.2.5' do
    it 'calls multiple on_fulfill callbacks in order of definition' do
      order = []
      on_fulfill = proc do |i, val|
        order << i
        expect(val).to eq(value)
      end

      subject.then(on_fulfill.curry[1])
      subject.then(on_fulfill.curry[2])

      subject.fulfill(value)
      subject.then(on_fulfill.curry[3])

      expect(order).to eq([1, 2, 3])
    end

    it 'calls multiple on_reject callbacks in order of definition' do
      order = []
      on_reject = proc do |i, reas|
        order << i
        expect(reas).to eq(reason)
      end

      subject.then(nil, on_reject.curry[1])
      subject.then(nil, on_reject.curry[2])

      subject.reject(reason)
      subject.then(nil, on_reject.curry[3])

      expect(order).to eq([1, 2, 3])
    end
  end

  describe '3.2.6' do
    let(:error) { StandardError.new }
    let(:returned_promise) { Promise.new }

    it 'returns promise2' do
      expect(subject.then).to be_a(Promise)
      expect(subject.then).not_to eq(subject)
    end

    it 'fulfills promise2 with value returned by on_fulfill' do
      promise2 = subject.then(proc { |_| other_value })
      subject.fulfill(value)

      expect(promise2).to be_fulfilled
      expect(promise2.value).to eq(other_value)
      expect(promise2.backtrace).to be(subject.backtrace)
    end

    it 'fulfills promise2 with value returned by on_reject' do
      promise2 = subject.then(nil, proc { |_| other_value })
      subject.reject(reason)

      expect(promise2).to be_fulfilled
      expect(promise2.value).to eq(other_value)
      expect(promise2.backtrace).to be(subject.backtrace)
    end

    it 'rejects promise2 with error raised by on_fulfill' do
      promise2 = subject.then(proc { |_| raise error })
      expect { subject.fulfill(value) }.to raise_error(error)

      expect(promise2).to be_rejected
      expect(promise2.reason).to eq(error)
      expect(promise2.backtrace).to be(subject.backtrace)
    end

    it 'rejects promise2 with error raised by on_reject' do
      promise2 = subject.then(nil, proc { |_| raise error })
      expect { subject.reject(reason) }.to raise_error(error)

      expect(promise2).to be_rejected
      expect(promise2.reason).to eq(error)
      expect(promise2.backtrace).to be(subject.backtrace)
    end

    describe 'on_fulfill returns promise' do
      it 'makes promise2 assume fulfilled state of returned promise' do
        promise2 = subject.then(proc { |_| returned_promise })

        subject.fulfill(value)
        expect(promise2).to be_pending

        returned_promise.fulfill(other_value)
        expect(promise2).to be_fulfilled
        expect(promise2.value).to eq(other_value)
        expect(promise2.backtrace).to be(returned_promise.backtrace)
      end

      it 'makes promise2 assume rejected state of returned promise' do
        promise2 = subject.then(proc { |_| returned_promise })

        subject.fulfill(value)
        expect(promise2).to be_pending

        returned_promise.reject(other_reason)
        expect(promise2).to be_rejected
        expect(promise2.reason).to eq(other_reason)
        expect(promise2.backtrace).to be(returned_promise.backtrace)
      end
    end

    describe 'on_reject returns promise' do
      it 'makes promise2 assume fulfilled state of returned promise' do
        promise2 = subject.then(nil, proc { |_| returned_promise })

        subject.reject(reason)
        expect(promise2).to be_pending

        returned_promise.fulfill(other_value)
        expect(promise2).to be_fulfilled
        expect(promise2.value).to eq(other_value)
        expect(promise2.backtrace).to be(returned_promise.backtrace)
      end

      it 'makes promise2 assume rejected state of returned promise' do
        promise2 = subject.then(nil, proc { |_| returned_promise })

        subject.reject(reason)
        expect(promise2).to be_pending

        returned_promise.reject(other_reason)
        expect(promise2).to be_rejected
        expect(promise2.reason).to eq(other_reason)
        expect(promise2.backtrace).to be(returned_promise.backtrace)
      end
    end

    describe 'without on_fulfill' do
      it 'fulfill promise2 with fulfillment value' do
        promise2 = subject.then
        subject.fulfill(value)

        expect(promise2).to be_fulfilled
        expect(promise2.value).to eq(value)
        expect(promise2.backtrace).to be(subject.backtrace)
      end
    end

    describe 'without on_reject' do
      it 'rejects promise2 with rejection reason' do
        promise2 = subject.then
        subject.reject(reason)

        expect(promise2).to be_rejected
        expect(promise2.reason).to eq(reason)
        expect(promise2.backtrace).to be(subject.backtrace)
      end
    end
  end

  describe 'extras' do
    describe '#progress' do
      let(:status) { double('status') }

      it 'calls the callbacks in the order of calls to #on_progress' do
        order = []
        block = proc do |i, stat|
          order << i
          expect(stat).to eq(status)
        end

        subject.on_progress(&block.curry[1])
        subject.on_progress(&block.curry[2])
        subject.on_progress(&block.curry[3])
        subject.progress(status)

        expect(order).to eq([1, 2, 3])
      end

      it 'does not call back unless pending' do
        called = false
        subject.on_progress { |_| called = true }
        subject.fulfill(value)

        subject.progress(status)
        expect(called).to eq(false)
      end
    end

    describe '#fulfill' do
      it 'does not return anything' do
        expect(subject.fulfill(nil)).to eq(nil)
      end

      it 'does not require a value' do
        subject.fulfill
        expect(subject.value).to be(nil)
      end

      it 'sets the backtrace' do
        subject.fulfill
        expect(subject.backtrace.join)
          .to include(__FILE__ + ':' + (__LINE__ - 2).to_s)
      end
    end

    describe '#reject' do
      it 'does not return anything' do
        expect(subject.reject(nil)).to eq(nil)
      end

      it 'does not require a reason' do
        subject.reject
        expect(subject.reason).to be(Promise::Error)
      end

      it 'sets the backtrace' do
        subject.reject
        expect(subject.backtrace.join)
          .to include(__FILE__ + ':' + (__LINE__ - 2).to_s)
      end
    end

    describe '#sync' do
      it 'waits for fulfillment' do
        allow(subject).to receive(:wait) { subject.fulfill(value) }
        expect(subject.sync).to be(value)
      end

      it 'waits for rejection' do
        allow(subject).to receive(:wait) { subject.reject(reason) }
        expect { subject.sync }.to raise_error(reason)
      end

      it 'waits if pending' do
        subject.fulfill(value)
        expect(subject).not_to receive(:wait)
        expect(subject.sync).to be(value)
      end
    end

    describe '.resolve' do
      it 'returns a fulfilled promise from a non-promise' do
        promise = Promise.resolve(123)
        expect(promise.fulfilled?).to eq(true)
        expect(promise.value).to eq(123)
      end

      it 'assumes the state of a given promise' do
        promise = Promise.new
        new_promise = Promise.resolve(promise)
        expect(new_promise.pending?).to eq(true)
        promise.fulfill(42)
        expect(new_promise.fulfilled?).to eq(true)
        expect(new_promise.value).to eq(42)
      end
    end
  end
end
