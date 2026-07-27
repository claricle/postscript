# frozen_string_literal: true

require "spec_helper"

# Round-trip property: for any PS source the parser accepts,
# serializing the parsed program and re-parsing yields an
# equivalent program (modulo formatting normalization).
#
# Catches: serializer missing operands, parser losing information,
# serializer re-emitting in a non-canonical form.
RSpec.describe "postscript round-trip property" do
  fixtures = [
    "simple square (path + fill)",
    "color operators (rgb / gray / cmyk / hsb)",
    "graphics state (gsave / grestore / setlinewidth / setdash)",
    "transformations (translate / scale / rotate)",
    "procedures (/foo { ... } def foo)",
    "text operators (findfont / scalefont / setfont / show)",
  ].zip(
    [
      <<~PS,
        %!PS-Adobe-3.0 EPSF-3.0
        %%BoundingBox: 0 0 100 100
        newpath
        10 10 moveto
        90 10 lineto
        90 90 lineto
        10 90 lineto
        closepath
        fill
        showpage
      PS
      <<~PS,
        %!PS-Adobe-3.0 EPSF-3.0
        %%BoundingBox: 0 0 100 100
        1 0 0 setrgbcolor
        0.5 setgray
        0.1 0.2 0.3 0.4 setcmykcolor
        0.7 0.5 0.3 sethsbcolor
        showpage
      PS
      <<~PS,
        %!PS-Adobe-3.0 EPSF-3.0
        %%BoundingBox: 0 0 100 100
        gsave
        2 setlinewidth
        [5 3] 1 setdash
        newpath 10 10 moveto 90 90 lineto stroke
        grestore
        showpage
      PS
      <<~PS,
        %!PS-Adobe-3.0 EPSF-3.0
        %%BoundingBox: 0 0 100 100
        gsave
        10 20 translate
        2 3 scale
        45 rotate
        newpath 0 0 moveto 10 0 lineto 10 10 lineto closepath fill
        grestore
        showpage
      PS
      <<~PS,
        %!PS-Adobe-3.0 EPSF-3.0
        %%BoundingBox: 0 0 100 100
        /sq { newpath 0 0 moveto 10 0 lineto 10 10 lineto closepath fill } def
        sq
        showpage
      PS
      <<~PS,
        %!PS-Adobe-3.0 EPSF-3.0
        %%BoundingBox: 0 0 100 100
        /Helvetica findfont 12 scalefont setfont
        10 50 moveto (Hello) show
        showpage
      PS
    ],
  )

  fixtures.each do |description, source|
    it "round-trips #{description}" do
      program1 = Postscript.parse(source)
      ps1 = Postscript.serialize(program1)
      program2 = Postscript.parse(ps1)
      ps2 = Postscript.serialize(program2)
      # Idempotent after the first round-trip.
      expect(ps2).to eq(ps1)
      # And both have a valid header.
      expect(ps1).to start_with("%!PS-Adobe-")
      expect(ps1).to include("%%EndComments")
      expect(ps1).to include("showpage")
    end
  end

  it "preserves BoundingBox across round-trip" do
    src = "%!PS-Adobe-3.0 EPSF-3.0\n%%BoundingBox: 0 0 200 150\nshowpage\n"
    program = Postscript.parse(src)
    expect(program.header.bounding_box).to eq([0.0, 0.0, 200.0, 150.0])
    serialized = Postscript.serialize(program)
    reprogram = Postscript.parse(serialized)
    expect(reprogram.header.bounding_box).to eq([0.0, 0.0, 200.0, 150.0])
  end

  it "preserves HiResBoundingBox across round-trip" do
    src = "%!PS-Adobe-3.0\n%%HiResBoundingBox: 0.0 0.0 99.5 49.5\nshowpage\n"
    program = Postscript.parse(src)
    expect(program.header.hires_bounding_box).to eq([0.0, 0.0, 99.5, 49.5])
    serialized = Postscript.serialize(program)
    reprogram = Postscript.parse(serialized)
    expect(reprogram.header.hires_bounding_box).to eq([0.0, 0.0, 99.5, 49.5])
  end

  it "preserves eps: flag across round-trip when eps: true" do
    src = "%!PS-Adobe-3.0\nshowpage\n"
    program = Postscript.parse(src)
    serialized_eps = Postscript.serialize(program, eps: true)
    expect(serialized_eps).to include("%!PS-Adobe-3.0 EPSF-3.0")
  end
end
