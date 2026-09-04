# frozen_string_literal: true

module Fastererer
  # Query surface every receiver answers; includers override only what is true for their type
  module Receiver
    def call_name = nil
    def name = nil
    def block? = false
    def arguments = []
    def range? = false
    def array? = false
    def hash? = false
  end
end
