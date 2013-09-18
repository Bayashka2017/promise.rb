# encoding: utf-8

require 'promise/version'

class Promise
  attr_reader :state, :value, :reason

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

  def then(on_fulfill = nil, on_reject = nil)
    callback = build_callback(on_fulfill, on_reject)
    add_callback(callback)

    callback[2]
  end

  def fulfill(value)
    if pending?
      fulfill!(value)
      @callbacks.each { |callback| dispatch_fulfill(callback) }
    end
  end

  def reject(reason)
    if pending?
      reject!(reason)
      @callbacks.each { |callback| dispatch_reject(callback) }
    end
  end

  private

  def build_callback(on_fulfill, on_reject)
    [on_fulfill || default_block, on_reject || default_block, Promise.new]
  end

  def default_block
    proc { |arg| arg }
  end

  def add_callback(callback)
    @callbacks << callback
    dispatch(callback)
  end

  def fulfill!(value)
    @state = :fulfilled
    @value = value.freeze
  end

  def reject!(reason)
    @state = :rejected
    @reason = reason.freeze
  end

  def dispatch(callback)
    if fulfilled?
      dispatch_fulfill(callback)
    elsif rejected?
      dispatch_reject(callback)
    end
  end

  def dispatch_fulfill(callback)
    run(callback[0], value, callback[2])
  end

  def dispatch_reject(callback)
    run(callback[1], reason, callback[2])
  end

  def run(block, arg, next_promise)
    begin
      result = block.call(arg)
    rescue => error
      next_promise.reject(error)
      raise error
    end

    next_promise.fulfill(result)
  end
end
