function feeder = ieee4_build(connection)
%IEEE4_BUILD Build the IEEE 4-node feeder with the given transformer
%   connection ("GrY-GrY" or "D-GrY").
D = ieee4_data();
switch string(connection)
    case "GrY-GrY"
        tx = mgtwin.TransformerGYGY(kvll_hi=12.47, kvll_lo=4.16, s_mva=6.0, r_pct=1.0, x_pct=6.0);
    case "D-GrY"
        tx = mgtwin.TransformerDGY(kvll_hi=12.47, kvll_lo=4.16, s_mva=6.0, r_pct=1.0, x_pct=6.0);
    otherwise
        error("mgtwin:ValueError", "unknown connection '%s'", string(connection));
end
feeder = mgtwin.RadialFeeder( ...
    v_source_ln=mgtwin.balancedSourceLn(12.47), ...
    elements={mgtwin.LineSegment(D.Z_Y, 2000.0), tx, mgtwin.LineSegment(D.Z_Y, 2500.0)}, ...
    load_kw=D.LOAD_KW, load_pf=D.LOAD_PF);
end
