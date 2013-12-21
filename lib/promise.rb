# encoding: utf-8

require 'promise/version'

require 'promise/callback'
require 'promise/progress'

class Promise
  include Promise::Progress

  attr_reader :state, :value, :reason, :backtrace

  def initialize
    @state = :pending
    @callbacks = []
  end

  def pending?
    @state == :pending
  end

  def fulfilled?
    @state == :fulfilled
  end

  def rejected?
    @state == :rejected
  end

  def then(on_fulfill = nil, on_reject = nil, &block)
    on_fulfill ||= block
    next_promise = Promise.new

    add_callback { Callback.new(on_fulfill, on_reject, next_promise) }
    next_promise
  end

  def add_callback(&generator)
    if pending?
      @callbacks << generator
    else
      dispatch!(generator.call)
    end
  end

  def sync
    wait if pending?
    raise reason if rejected?
    value
  end

  def fulfill(value = nil, backtrace = nil)
    dispatch(backtrace) do
      @state = :fulfilled
      @value = value
    end
  end

  def reject(reason = RuntimeError, backtrace = nil)
    dispatch(backtrace) do
      @state = :rejected
      @reason = reason
    end
  end

  def dispatch(backtrace)
    if pending?
      yield
      @backtrace = backtrace || caller
      @callbacks.each { |generator| dispatch!(generator.call) }
      nil
    end
  end

  def dispatch!(callback)
    defer { callback.dispatch(self) }
  end

  def defer
    yield
  end
end
