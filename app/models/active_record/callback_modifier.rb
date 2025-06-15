module ActiveRecord::CallbackModifier

  ##
  # Low level override of after_create and after_update, and touch callbacks.
  # Useful for batch record changes that are approved safe to run without callbacks.
  def without_create_and_update_callbacks(record, redefine = true)
    existing_create = record.method(:_run_create_callbacks)
    existing_update = record.method(:_run_update_callbacks)
    existing_touch = record.method(:_run_touch_callbacks)
    record.define_singleton_method(:_run_create_callbacks, ->(&block){ block.call })
    record.define_singleton_method(:_run_update_callbacks, ->(&block){ block.call })
    record.define_singleton_method(:_run_touch_callbacks, ->(&block){ block.call })

    yield
  ensure
    if redefine
      record.define_singleton_method(:_run_create_callbacks, existing_create)
      record.define_singleton_method(:_run_update_callbacks, existing_update)
      record.define_singleton_method(:_run_touch_callbacks, existing_touch)
    end
  end
end