module Slanger
  class PrivateSubscription < Subscription
    def subscribe
      return handle_invalid_signature if auth && invalid_signature?

      super
    end
  end
end
