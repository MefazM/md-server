def lerp( b,  a,  t)
  return ((b-a) * t).floor
end

t = 20
c = 400

1000.times do

  c += lerp( t,  c,  0.08)

  puts(c)

end