#
# spijjeno from: http://stackoverflow.com/questions/8379596/how-do-i-convert-a-ruby-hash-so-that-all-of-its-keys-are-symbols
#
class Hash
  def recursive_symbolize_keys!
    self.replace _recursive_symbolize_keys self
  end

  # private

  def _recursive_symbolize_keys _hash
    case _hash
    when Hash
      Hash[
        _hash.map do |key, value|
          [ key.respond_to?(:to_sym) ? key.to_sym : key, _recursive_symbolize_keys(value) ]
        end
      ]
    when Enumerable
      _hash.map { |value| _recursive_symbolize_keys(value) }
    else
      _hash
    end
  end
end