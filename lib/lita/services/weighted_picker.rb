module Lita
  module Services
    class WeightedPicker
      def initialize(weighted_hash)
        raise NonPositiveKarmaError unless weighted_hash.values.all?(&:positive?)
        @weighted_hash = weighted_hash
        @total_elements = weighted_hash.count
      end

      def sample_one
        return if @weighted_hash.empty?

        u = rand
        winner = cumulative_weighted_hash.find { |k, _| k > u }.last
        remove(winner)
      end

      def sample(n)
        raise NegativeSampleSize if n.negative?

        winners = []

        sample_size = [n, @total_elements].min

        return winners if sample_size.zero?

        sample_size.times do
          winner = sample_one
          unless winner.nil? || winners.include?(winner)
            winners.push winner
          end
        end

        winners
      end

      private

      def cumulative_weighted_hash
        total_points = @weighted_hash.values.reduce(0, :+).to_f
        u = 0.0
        @weighted_hash.map { |k, v| [u += v / total_points, k] }.to_h
      end

      def min
        @weighted_hash.values.min
      end

      def max
        @weighted_hash.values.max
      end

      def remove(winner)
        @weighted_hash = @weighted_hash.reject { |k, _| k == winner }
        winner
      end
    end

    class NonPositiveKarmaError < StandardError; end
    class NegativeSampleSize < StandardError; end
  end
end
