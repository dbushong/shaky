# CoffeeScript port by David Bushong <david@bushong.net>
#
# Copyright 2012 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FONT = "20pt 'Gloria Hallelujah'"

# ShakyCanvas provides a way of drawing shaky lines on a normal
# HTML5 canvas element.
class ShakyCanvas
  constructor: (canvas) ->
    @ctx = canvas.getContext('2d')
    @ctx.lineWidth = 3
    @ctx.font = FONT
    @ctx.textBaseline = 'middle'
  
  moveTo: (@x0, @y0) ->

  lineTo: (x1, y1) ->
    @shakyLine @x0, @y0, x1, y1
    @moveTo x1, y1

  # Draw a shaky line between (x0, y0) and (x1, y1).
  shakyLine: (x0, y0, x1, y1) ->
    # Let $v = (d_x, d_y)$ be a vector between points $P_0 = (x_0, y_0)$ and $P_1 = (x_1, y_1)$.
    dx = x1 - x0
    dy = y1 - y0

    # Let $l$ be the length of $v$.
    l = Math.sqrt dx * dx + dy * dy

    # Now we need to pick two random points that are placed
    # on different sides of the line that passes through
    # $P_1$ and $P_2$ and not very far from it if length of
    # $P_1 P_2$ is small.
    K = Math.sqrt(l) / 1.5
    k1 = Math.random()
    k2 = Math.random()
    l3 = Math.random() * K
    l4 = Math.random() * K

    # Point $P_3$: pick a random point on the line between $P_0$ and $P_1$,
    # then shift it by vector $\frac{l_1}{l} (d_y, -d_x)$ which is a line's normal.
    x3 = x0 + dx * k1 + dy/l * l3
    y3 = y0 + dy * k1 - dx/l * l3

    # Point $P_3$: pick a random point on the line between $P_0$ and $P_1$,
    # then shift it by vector $\frac{l_2}{l} (-d_y, d_x)$ which also is a line's normal
    # but points into opposite direction from the one we used for $P_3$.
    x4 = x0 + dx * k2 - dy/l * l4
    y4 = y0 + dy * k2 + dx/l * l4

    # Draw a bezier curve through points $P_0$, $P_3$, $P_4$, $P_1$.
    # Selection of $P_3$ and $P_4$ makes line "jerk" a little
    # between them but otherwise it will be mostly straight thus
    # creating illusion of being hand drawn.
    @ctx.moveTo x0, y0
    @ctx.bezierCurveTo x3, y3, x4, y4, x1, y1

  # Draw a shaky bulb (used for line endings).
  bulb: (x0, y0) ->
    fuzziness = -> Math.random() * 2 - 1

    for i in [0..2]
      @beginPath()
      @ctx.arc x0 + fuzziness(), y0 + fuzziness(), 5, 0, Math.PI * 2, true
      @ctx.closePath()
      @ctx.fill()

  # Draw a shaky arrowhead at the (x1, y1) as an ending
  # for the line from (x0, y0) to (x1, y1).
  arrowhead: (x0, y0, x1, y1) ->
    dx = x0 - x1
    dy = y0 - y1

    alpha =
      if dy is 0
        if dx < 0 then -Math.PI else 0
      else Math.atan dy / dx

    alpha3 = alpha + 0.5
    alpha4 = alpha - 0.5

    l3 = 20
    x3 = x1 + l3 * Math.cos(alpha3)
    y3 = y1 + l3 * Math.sin(alpha3)

    @beginPath()
    @moveTo x3, y3
    @lineTo x1, y1
    @stroke()

    l4 = 20
    x4 = x1 + l4 * Math.cos(alpha4)
    y4 = y1 + l4 * Math.sin(alpha4)

    @beginPath()
    @moveTo x4, y4
    @lineTo x1, y1
    @stroke()

  # Forward some methods to rendering context.
  # Ideally we would just use something like
  #
  #   noSuchMethod(mirror) => mirror.invokeOn(mirror);
  #
  # But that does not work
  # So for now we will just use manual forwarding.
  beginPath: -> @ctx.beginPath()
  stroke: -> @ctx.stroke()
  
  setStrokeStyle: (val) -> @ctx.strokeStyle = val
  setFillStyle: (val) -> @ctx.fillStyle = val
  
  fillText: (args...) -> @ctx.fillText args...

#
# Code below converts ASCII art into Line and Text elements.
#

# Size in pixels for a sigle character cell of ASCII art. 
CELL_SIZE = 15

X = (x) -> x * CELL_SIZE + (CELL_SIZE / 2)
Y = (y) -> y * CELL_SIZE + (CELL_SIZE / 2)

# Auxiliary Point class used during parsing. 
# Unfortunately Dart does not support structural classes or
# local classes so I had to polute library namespace with it.
class Point
  constructor: (@x, @y) ->

# Line from (x0, y0) to (x1, y1) with the given color and decolartions
# at the start and end.
class Line
  constructor: (@x0, @y0, @start, @x1, @y1, @end, @color) ->

  draw: (ctx) ->
    ctx.setStrokeStyle @color
    ctx.setFillStyle @color
    ctx.beginPath()
    ctx.moveTo X(@x0), Y(@y0)
    ctx.lineTo X(@x1), Y(@y1)
    ctx.stroke()
    @_ending ctx, @start, X(@x1), Y(@y1), X(@x0), Y(@y0)
    @_ending ctx, @end, X(@x0), Y(@y0), X(@x1), Y(@y1)
  
  # Draw given type of ending on the (x1, y1).
  _ending: (ctx, type, x0, y0, x1, y1) ->
    switch type
      when 'circle' then ctx.bulb x1, y1
      when 'arrow'  then ctx.arrowhead x0, y0, x1, y1

# Text annotation at (x0, y0) with the given color.
class Text
  constructor: (@x0, @y0, @text, @color) ->
  
  draw: (ctx) ->
    ctx.setFillStyle @color
    ctx.fillText @text, X(@x0), Y(@y0)

# Parses given ASCII art string into a list of figures.
parseASCIIArt = (string) ->
  lines = string.split '\n'

  height = lines.length
  width  = Math.max (line.length for line in lines)...

  data = []  # Matrix containing ASCII art.
  
  # Get a character from the array or null if we are out of bounds.
  # Useful in places where we inspect character's neighbors and peek
  # out of bounds for boundary characters.
  at = (y, x) -> data[y]?[x]

  # Convert strings into a mutable matrix of characters.
  for line,y in lines
    data[y] = line.split ''
    data[y][x] = ' ' for x in [line.length...width]

  # Returns true iff the character can be part of the line.
  isPartOfLine = (x, y) ->
    c = at y, x
    c is '|' or c is '-' or c is '+' or c is '~' or c is '!'

  # If character represents a color modifier returns CSS color.
  toColor = (x, y) ->
    switch at y, x
      when '~', '!' then '#666'

  # Returns true iff characters is line ending decoration.
  isLineEnding = (x, y) ->
    c = at y, x
    c is '*' or c is '<' or c is '>' or c is '^' or c is 'v'

  # Finds a character that belongs to unextracted line.
  findLineChar = ->
    for y in [0...height]
      for x in [0...width]
        if data[y][x] is '|' or data[y][x] is '-'
          return new Point x, y

  # Converts line's character to the direction of line's growth.
  dir = { '-': new Point(1, 0), '|': new Point(0, 1) }

  # Erases character that belongs to the extracted line.
  eraseChar = (x, y, dx, dy) ->
    switch at y, x
      when '|', '-', '*', '>', '<', '^', 'v', '~', '!'
        data[y][x] = ' '
      when '+'
        dx = 1 - dx
        dy = 1 - dy

        data[y][x] = ' '
        switch at y - dy, x - dx
          when '|', '!', '+'
            data[y][x] = '|'
            return
          when '-', '~'
            data[y][x] = '-'
            return

        switch at y + dy, x + dx
          when '|', '!', '+' then data[y][x] = '|'
          when '-', '~'      then data[y][x] = '-'

  # Erase the given extracted line.
  erase = (line) ->
    dx = if line.x0 isnt line.x1 then 1 else 0
    dy = if line.y0 isnt line.y1 then 1 else 0

    if dx isnt 0 or dy isnt 0
      x = line.x0 + dx
      y = line.y0 + dy
      x_ = line.x1 - dx
      y_ = line.y1 - dy
      while x <= x_ and y <= y_
        eraseChar x, y, dx, dy
        x += dx
        y += dy
      eraseChar line.x0, line.y0, dx, dy
      eraseChar line.x1, line.y1, dx, dy
    else
      eraseChar line.x0, line.y0, dx, dy

  figures = []  # List of extracted figures.
  
  # Extract a single line and erase it from the ascii art matrix.
  extractLine = ->
    ch = findLineChar()
    return false unless ch?

    d = dir[data[ch.y][ch.x]]

    # Find line's start by advancing in the oposite direction.
    x0 = ch.x
    y0 = ch.y
    color = null
    while isPartOfLine x0 - d.x, y0 - d.y
      x0 -= d.x
      y0 -= d.y
      color ?= toColor x0, y0

    start = null
    if isLineEnding x0 - d.x, y0 - d.y
      # Line has a decorated start. Extract is as well.
      x0 -= d.x
      y0 -= d.y
      start = if data[y0][x0] is '*' then 'circle' else 'arrow'

    # Find line's end by advancing forward in the given direction. 
    x1 = ch.x
    y1 = ch.y
    while isPartOfLine x1 + d.x, y1 + d.y
      x1 += d.x
      y1 += d.y
      color ?= toColor x1, y1

    end = null
    if isLineEnding x1 + d.x, y1 + d.y
      # Line has a decorated end. Extract it.
      x1 += d.x
      y1 += d.y
      end = if data[y1][x1] is '*' then 'circle' else 'arrow'

    # Create line object and erase line from the ascii art matrix.
    line = new Line x0, y0, start, x1, y1, end, color ? 'black'
    figures.push line
    erase line

    # Adjust line start and end to accomodate for arrow endings.
    # Those should not intersect with their targets but should touch them
    # instead. Should be done after erasure to ensure that erase deletes
    # arrowheads.
    if start is 'arrow'
      line.x0 -= d.x
      line.y0 -= d.y

    if end is 'arrow'
      line.x1 += d.x
      line.y1 += d.y

    true

  # Extract all non space characters that were left after line extraction
  # as text objects.
  extractText = ->
    for y in [0...height]
      x = 0
      while x < width
        if data[y][x] is ' '
          x++
        else
          # Find the end of the text annotation by searching for a space.
          start = end = x
          while end < width and data[y][end] isnt ' '
            end++

          text = data[y][start...end].join ''

          # Check if it can be concatenated with a previously found text annotation.
          prev = figures[figures.length - 1]
          if prev?.constructor.name is 'Text' and
              prev.x0 + prev.text.length + 1 is start
            # If they touch concatentate them.
            prev.text = "#{prev.text} #{text}"
          else
            # Look for a grey color modifiers.
            color = 'black'
            if text[0] is '\\' and text[text.length - 1] is '\\'
              text = text.substring 1, text.length-1
              color = '#666'
            figures.push new Text(x, y, text, color)
          x = end

  while extractLine() then # Extract all lines.
  extractText()  # Extract all text.

  figures

doc = document
$ = (id) -> doc.getElementById id

# Draw a diagram from the ascii art contained in the #textarea.
window.drawDiagram = ->
  figures = parseASCIIArt $('textarea').value

  # Compute required canvas size.
  width = 0
  height = 0
  for figure in figures
    if figure.constructor.name is 'Line'
      width = Math.max width, X(figure.x1 + 1)
      height = Math.max height, Y(figure.y1 + 1)
  
  canvas = $ 'canvas'

  canvas.width = width
  canvas.height = height
  
  ctx = new ShakyCanvas canvas
  figure.draw(ctx) for figure in figures

# start main code
textarea = $('textarea')
textarea.addEventListener 'change', drawDiagram
textarea.addEventListener 'keyup',  drawDiagram

$('save').addEventListener 'click', ->
  a = doc.createElement 'a'
  a.href = $('canvas').toDataURL('image/png')
  a.download = $('name').value
  doc.body.appendChild a
  setTimeout (-> doc.body.removeChild a), 1000
  try
    a.click()
  catch e
    alert "couldn't click"
    #a.$dom_dispatchEvent(new html.Event("click"));

drawDiagram() if FONTS_ACTIVE?
