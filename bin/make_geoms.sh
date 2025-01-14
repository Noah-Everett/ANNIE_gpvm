main() {
OUTDIR=""
DWTH=""
MATERIAL=""
SHAPE=""
STATE=""
DENSITY=""
NFILES=""

echo "Processing command line arguments."
for i in "$@"; do
  case $i in
    --outDir=*             ) export OUTDIR="${i#*=}"      shift    ;;
    --containerThickness=* ) export DWTH="${i#*=}"        shift    ;;
    --material=*           ) export MATERIAL="${i#*=}"    shift    ;;
    --shape=*              ) export SHAPE="${i#*=}"       shift    ;;
    --rad_min=*            ) export RAD_MIN="${i#*=}"     shift    ;;
    --rad_max=*            ) export RAD_MAX="${i#*=}"     shift    ;;
    --rad_delta=*          ) export RAD_DELTA="${i#*=}"   shift    ;;
    --state=*              ) export STATE="${i#*=}"       shift    ;;
    --height=*             ) export HEIGHT="${i#*=}"      shift    ;;
    --density=*            ) export DENSITY="${i#*=}"     shift    ;;
    -*                     ) echo "Unknown option \"$i\"" return 1 ;;
  esac
done

if [ -z ${OUTDIR} ]; then
  echo "Use \`--outDir=</output/dir>\` to set the output directory"
  return 1;
fi

if [[ -z ${MATERIAL} || ( ${MATERIAL} != "vacuum" && ${MATERIAL} != "argon" && ${MATERIAL} != "water" ) ]]; then
  echo "Use either \`--material=argon\`, \`--material=water\`, or \`--material=vacuum\`."
  return 1
fi

if [[ -z ${SHAPE} || ( ${SHAPE} != "tube" && ${SHAPE} != "sphere" ) ]]; then
  echo "Use either \`--shape=tube\` or \`--shape=sphere\`."
  return 1
fi

if [ -z ${RAD_MIN} ]; then
  echo "Use \`--rad_min=<minimum radius in mm>\`."
  return 1
fi

if [ -z ${RAD_MAX} ]; then
  echo "Use \`--rad_max=<maximum radius in mm>\`."
  return 1
fi

if [ -z ${RAD_DELTA} ]; then
  echo "Use \`--rad_delta=<delta radius in mm>\`."
  return 1
fi

if [[ ${MATERIAL} == "argon" && ( -z ${STATE} || ( ${STATE} != "gas" && ${STATE} != "liquid" ) ) ]]; then
  echo "Use either \`--state=gas\` or \`--state=liquid\`."
  return 1
fi

if [[ ${MATERIAL} == "argon" && ${STATE} == "gas" && -z ${DENSITY} ]]; then
  echo "Use \`--density=#\` to set the density of the argon gas."
  return 1
else
  export DENSITY="0$(echo "0.00166201*${DENSITY}" | bc)"
fi

if [[ ${SHAPE} == "tube" && -z ${HEIGHT} ]]; then
  echo "Use \`--height=<height in mm>\` to set the height of the tube."
  return 1;
fi

if [ -z ${DWTH} ]; then
  echo "Setting dewar thickness to \`4.76\`."
  export DWTH="4.76"
fi

mkdir $OUTDIR
cat <<EOF > $OUTDIR/make_geoms.legend
All gdml files in `${OUTDIR}` have the following properties:
  Shape: ${SHAPE}
  Material: ${MATERIAL}
  Argon State (if argon): ${STATE}
  Argon Density (if argon gas) (*1.66E-3 g/cm^3): ${DENSITY}
annie_v02_<nFile>.gdml ---> y=<dewar y> rad=<dewar rad>
EOF

export c=0
for (( rad=$RAD_MIN; ( rad<=$RAD_MAX && rad>=0 ); rad+=$RAD_DELTA )); do
  mkfile_geom
  update_legend
  c=$((c+1))
done
}

update_legend() {
echo "annie_v02_${c}.gdml ---> y=$(echo 1519.24 - 600 - 500 | bc) rad=$rad" >> $OUTDIR/make_geoms.legend
}

mkfile_geom() {
if [[ ${MATERIAL} == "argon" && ${STATE} == "gas" ]]; then
  G4_Ar=$(cat <<-END
    <material name="G4_Ar" state="gas">
      <T unit="K" value="293.15"/>
      <MEE unit="eV" value="188.000"/>
      <D unit="g/cm3" value="${DENSITY}"/>
      <fraction n="1" ref="Ar"/>
    </material>
END
)
GDMLMATERIAL="G4_Ar"
elif [[ ${MATERIAL} == "argon" && ${STATE} == "liquid" ]]; then
  G4_Ar=$(cat <<-END
    <material name="G4_Ar" state="liquid">
      <T unit="K" value="87.45"/>
      <MEE unit="eV" value="188.000"/>
      <D unit="g/cm3" value="1.396"/>
      <fraction n="1" ref="Ar"/>
    </material>
END
)
GDMLMATERIAL="G4_Ar"
elif [[ ${MATERIAL} == "vacuum" ]]; then
  G4_Ar=""
  GDMLMATERIAL="Vacuum"
elif [[ ${MATERIAL} == "water" ]]; then
  G4_Ar=""
  GDMLMATERIAL="TankWater"
fi

if [ ${SHAPE} == "tube" ]; then
  TARGON_LV="<tube aunit=\"deg\" deltaphi=\"360\" lunit=\"mm\" name=\"TARGON_S\" rmax=\"$(echo ${rad} - ${DWTH} | bc)\" rmin=\"0\" startphi=\"0\" z=\"$(echo ${HEIGHT} - ${DWTH} - ${DWTH} | bc)\"/>"
  TDEWAR_LV="<tube aunit=\"deg\" deltaphi=\"360\" lunit=\"mm\" name=\"TDEWAR_S\" rmax=\"${rad}\" rmin=\"0\" startphi=\"0\" z=\"${HEIGHT}\"/>"
elif [ ${SHAPE} == "sphere" ]; then
  TARGON_LV="<sphere aunit=\"deg\" lunit=\"mm\" name=\"TARGON_S\" rmax=\"$(echo ${rad} - ${DWTH} | bc)\" deltaphi=\"360\" deltatheta=\"180\"/>"
  TDEWAR_LV="<sphere aunit=\"deg\" lunit=\"mm\" name=\"TDEWAR_S\" rmax=\"${rad}\" deltaphi=\"360\" deltatheta=\"180\"/>"
fi

echo making and writing to $OUTDIR/annie_v02_${c}.gdml
cat <<EOF > $OUTDIR/annie_v02_${c}.gdml
<?xml version="1.0" encoding="UTF-8" standalone="no" ?>
<gdml xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://service-spi.web.cern.ch/service-spi/app/releases/GDML/schema/gdml.xsd">
  <define/>
  <materials>
    <isotope N="54" Z="26" name="Fe54">
      <atom unit="g/mole" value="53.9396"/>
    </isotope>
    <isotope N="56" Z="26" name="Fe56">
      <atom unit="g/mole" value="55.9349"/>
    </isotope>
    <isotope N="57" Z="26" name="Fe57">
      <atom unit="g/mole" value="56.9354"/>
    </isotope>
    <isotope N="58" Z="26" name="Fe58">
      <atom unit="g/mole" value="57.9333"/>
    </isotope>
    <isotope N="12" Z="6" name="C12">
      <atom unit="g/mole" value="12"/>
    </isotope>
    <isotope N="13" Z="6" name="C13">
      <atom unit="g/mole" value="13.0034"/>
    </isotope>
    <isotope N="14" Z="7" name="N14">
      <atom unit="g/mole" value="14.0031"/>
    </isotope>
    <isotope N="15" Z="7" name="N15">
      <atom unit="g/mole" value="15.0001"/>
    </isotope>
    <isotope N="16" Z="8" name="O16">
      <atom unit="g/mole" value="15.9949"/>
    </isotope>
    <isotope N="17" Z="8" name="O17">
      <atom unit="g/mole" value="16.9991"/>
    </isotope>
    <isotope N="18" Z="8" name="O18">
      <atom unit="g/mole" value="17.9992"/>
    </isotope>
    <isotope N="36" Z="18" name="Ar36">
      <atom unit="g/mole" value="35.9675"/>
    </isotope>
    <isotope N="38" Z="18" name="Ar38">
      <atom unit="g/mole" value="37.9627"/>
    </isotope>
    <isotope N="40" Z="18" name="Ar40">
      <atom unit="g/mole" value="39.9624"/>
    </isotope>
    <isotope N="1" Z="1" name="H1">
      <atom unit="g/mole" value="1.00782503081372"/>
    </isotope>
    <isotope N="2" Z="1" name="H2">
      <atom unit="g/mole" value="2.01410199966617"/>
    </isotope>
    <isotope N="23" Z="11" name="Na23">
      <atom unit="g/mole" value="22.9898"/>
    </isotope>
    <isotope N="24" Z="12" name="Mg24">
      <atom unit="g/mole" value="23.985"/>
    </isotope>
    <isotope N="25" Z="12" name="Mg25">
      <atom unit="g/mole" value="24.9858"/>
    </isotope>
    <isotope N="26" Z="12" name="Mg26">
      <atom unit="g/mole" value="25.9826"/>
    </isotope>
    <isotope N="27" Z="13" name="Al27">
      <atom unit="g/mole" value="26.9815"/>
    </isotope>
    <isotope N="28" Z="14" name="Si28">
      <atom unit="g/mole" value="27.9769"/>
    </isotope>
    <isotope N="29" Z="14" name="Si29">
      <atom unit="g/mole" value="28.9765"/>
    </isotope>
    <isotope N="30" Z="14" name="Si30">
      <atom unit="g/mole" value="29.9738"/>
    </isotope>
    <isotope N="39" Z="19" name="K39">
      <atom unit="g/mole" value="38.9637"/>
    </isotope>
    <isotope N="40" Z="19" name="K40">
      <atom unit="g/mole" value="39.964"/>
    </isotope>
    <isotope N="41" Z="19" name="K41">
      <atom unit="g/mole" value="40.9618"/>
    </isotope>
    <isotope N="40" Z="20" name="Ca40">
      <atom unit="g/mole" value="39.9626"/>
    </isotope>
    <isotope N="42" Z="20" name="Ca42">
      <atom unit="g/mole" value="41.9586"/>
    </isotope>
    <isotope N="43" Z="20" name="Ca43">
      <atom unit="g/mole" value="42.9588"/>
    </isotope>
    <isotope N="44" Z="20" name="Ca44">
      <atom unit="g/mole" value="43.9555"/>
    </isotope>
    <isotope N="46" Z="20" name="Ca46">
      <atom unit="g/mole" value="45.9537"/>
    </isotope>
    <isotope N="48" Z="20" name="Ca48">
      <atom unit="g/mole" value="47.9525"/>
    </isotope>
    <isotope N="10" Z="5" name="B10">
      <atom unit="g/mole" value="10.0129"/>
    </isotope>
    <isotope N="11" Z="5" name="B11">
      <atom unit="g/mole" value="11.0093"/>
    </isotope>
    <isotope N="152" Z="64" name="Gd152">
      <atom unit="g/mole" value="151.92"/>
    </isotope>
    <isotope N="154" Z="64" name="Gd154">
      <atom unit="g/mole" value="153.921"/>
    </isotope>
    <isotope N="155" Z="64" name="Gd155">
      <atom unit="g/mole" value="154.923"/>
    </isotope>
    <isotope N="156" Z="64" name="Gd156">
      <atom unit="g/mole" value="155.922"/>
    </isotope>
    <isotope N="157" Z="64" name="Gd157">
      <atom unit="g/mole" value="156.924"/>
    </isotope>
    <isotope N="158" Z="64" name="Gd158">
      <atom unit="g/mole" value="157.924"/>
    </isotope>
    <isotope N="160" Z="64" name="Gd160">
      <atom unit="g/mole" value="159.927"/>
    </isotope>
    <isotope N="32" Z="16" name="S32">
      <atom unit="g/mole" value="31.9721"/>
    </isotope>
    <isotope N="33" Z="16" name="S33">
      <atom unit="g/mole" value="32.9715"/>
    </isotope>
    <isotope N="34" Z="16" name="S34">
      <atom unit="g/mole" value="33.9679"/>
    </isotope>
    <isotope N="36" Z="16" name="S36">
      <atom unit="g/mole" value="35.9671"/>
    </isotope>
    <element name="K">
      <fraction n="0.932581" ref="K39"/>
      <fraction n="0.000117" ref="K40"/>
      <fraction n="0.067302" ref="K41"/>
    </element>
    <element name="Si">
      <fraction n="0.922296077703922" ref="Si28"/>
      <fraction n="0.0468319531680468" ref="Si29"/>
      <fraction n="0.0308719691280309" ref="Si30"/>
    </element>
    <element name="Silicon">
      <fraction n="0.922296077703922" ref="Si28"/>
      <fraction n="0.0468319531680468" ref="Si29"/>
      <fraction n="0.0308719691280309" ref="Si30"/>
    </element>
    <element name="Mg">
      <fraction n="0.7899" ref="Mg24"/>
      <fraction n="0.1" ref="Mg25"/>
      <fraction n="0.1101" ref="Mg26"/>
    </element>
    <element name="Al">
      <fraction n="1" ref="Al27"/>
    </element>
    <element name="Na">
      <fraction n="1" ref="Na23"/>
    </element>
    <element name="Sodium">
      <fraction n="1" ref="Na23"/>
    </element>
    <element name="H">
      <fraction n="0.999885" ref="H1"/>
      <fraction n="0.000115" ref="H2"/>
    </element>
    <element name="Hydrogen">
      <fraction n="0.999885" ref="H1"/>
      <fraction n="0.000115" ref="H2"/>
    </element>
    <element name="Carbon">
      <fraction n="0.9893" ref="C12"/>
      <fraction n="0.0107" ref="C13"/>
    </element>
    <element name="Iron_el">
      <fraction n="0.05845" ref="Fe54"/>
      <fraction n="0.91754" ref="Fe56"/>
      <fraction n="0.02119" ref="Fe57"/>
      <fraction n="0.00282" ref="Fe58"/>
    </element>
    <element name="Oxygen">
      <fraction n="0.99757" ref="O16"/>
      <fraction n="0.00038" ref="O17"/>
      <fraction n="0.00205" ref="O18"/>
    </element>
    <element name="Boron">
      <fraction n="0.199" ref="B10"/>
      <fraction n="0.801" ref="B11"/>
    </element>
    <element name="Aluminum">
      <fraction n="1" ref="Al27"/>
    </element>
    <element name="Ar">
      <fraction n="0.003365" ref="Ar36"/>
      <fraction n="0.000632" ref="Ar38"/>
      <fraction n="0.996003" ref="Ar40"/>
    </element>
    <element name="O">
      <fraction n="0.99757" ref="O16"/>
      <fraction n="0.00038" ref="O17"/>
      <fraction n="0.00205" ref="O18"/>
    </element>
    <element name="N">
      <fraction n="0.99632" ref="N14"/>
      <fraction n="0.00368" ref="N15"/>
    </element>
    <element name="C">
      <fraction n="0.9893" ref="C12"/>
      <fraction n="0.0107" ref="C13"/>
    </element>
    <element name="Fe">
      <fraction n="0.05845" ref="Fe54"/>
      <fraction n="0.91754" ref="Fe56"/>
      <fraction n="0.02119" ref="Fe57"/>
      <fraction n="0.00282" ref="Fe58"/>
    </element>
    <element name="Ca">
      <fraction n="0.96941" ref="Ca40"/>
      <fraction n="0.00647" ref="Ca42"/>
      <fraction n="0.00135" ref="Ca43"/>
      <fraction n="0.02086" ref="Ca44"/>
      <fraction n="4e-05" ref="Ca46"/>
      <fraction n="0.00187" ref="Ca48"/>
    </element>
    <element name="TankSteel_el">
      <fraction n="0.05845" ref="Fe54"/>
      <fraction n="0.91754" ref="Fe56"/>
      <fraction n="0.02119" ref="Fe57"/>
      <fraction n="0.00282" ref="Fe58"/>
    </element>
    <element name="Gd">
      <fraction n="0.0020" ref="Gd152"/>
      <fraction n="0.0218" ref="Gd154"/>
      <fraction n="0.1480" ref="Gd155"/>
      <fraction n="0.2047" ref="Gd156"/>
      <fraction n="0.1565" ref="Gd157"/>
      <fraction n="0.2486" ref="Gd158"/>
      <fraction n="0.2186" ref="Gd160"/>
    </element>
    <element name="S">
      <fraction n="0.9493" ref="S32"/>
      <fraction n="0.0076" ref="S33"/>
      <fraction n="0.0429" ref="S34"/>
      <fraction n="0.0002" ref="S36"/>
    </element>
    <material name="Gd_Sulfate" state="solid">
      <D unit="g/cm3" value="3.01"/>
      <fraction n="0.5218332025293563" ref="Gd"/>
      <fraction n="0.1596112715971746" ref="O"/>
      <fraction n="0.3185555258734691" ref="S"/>
    </material>
    <material name="Steel" state="solid">
      <MEE unit="eV" value="286"/>
      <D unit="g/cm3" value="7.874"/>
      <fraction n="1" ref="Fe"/>
    </material>
    <material name="Scinti" state="solid">
      <MEE unit="eV" value="65.9436601819466"/>
      <D unit="g/cm3" value="1.021"/>
      <fraction n="0.922577329294378" ref="C"/>
      <fraction n="0.0774226707056217" ref="H"/>
    </material>
    <material name="Iron" state="solid">
      <MEE unit="eV" value="286"/>
      <D unit="g/cm3" value="7.841"/>
      <fraction n="1" ref="Iron_el"/>
    </material>
    <material name="TankWater" state="solid">
      <MEE unit="eV" value="68.9984174679527"/>
      <D unit="g/cm3" value="1"/>
      <fraction n="0.111556300020840" ref="H"/>
      <fraction n="0.885452673059918" ref="O"/>
      <fraction n="0.002991026919242" ref="Gd_Sulfate"/>
    </material>
    <material name="TankSteel" state="solid">
      <MEE unit="eV" value="286"/>
      <D unit="g/cm3" value="7.841"/>
      <fraction n="1" ref="TankSteel_el"/>
    </material>
    <material name="G4_AIR" state="gas">
      <MEE unit="eV" value="85.7"/>
      <D unit="g/cm3" value="0.00120479"/>
      <fraction n="0.000124000124000124" ref="C"/>
      <fraction n="0.755267755267755" ref="N"/>
      <fraction n="0.231781231781232" ref="O"/>
      <fraction n="0.0128270128270128" ref="Ar"/>
    </material>
    <material Z="13" name="G4_Al" state="solid">
      <MEE unit="eV" value="166"/>
      <D unit="g/cm3" value="2.699"/>
      <atom unit="g/mole" value="26.9815"/>
    </material>
    <material name="G4_CONCRETE" state="solid">
      <MEE unit="eV" value="135.2"/>
      <D unit="g/cm3" value="2.3"/>
      <fraction n="0.01" ref="H"/>
      <fraction n="0.001" ref="C"/>
      <fraction n="0.529107" ref="O"/>
      <fraction n="0.016" ref="Na"/>
      <fraction n="0.002" ref="Mg"/>
      <fraction n="0.033872" ref="Al"/>
      <fraction n="0.337021" ref="Si"/>
      <fraction n="0.013" ref="K"/>
      <fraction n="0.044" ref="Ca"/>
      <fraction n="0.014" ref="Fe"/>
    </material>
    <material name="Dirt" state="solid">
      <MEE unit="eV" value="129.589427782907"/>
      <D unit="g/cm3" value="1.7"/>
      <fraction n="0.437" ref="O"/>
      <fraction n="0.257" ref="Si"/>
      <fraction n="0.222" ref="Na"/>
      <fraction n="0.049" ref="Al"/>
      <fraction n="0.02" ref="Fe"/>
      <fraction n="0.015" ref="K"/>
    </material>
    <material name="Glass" state="solid">
      <T unit="K" value="293.15"/>
      <MEE unit="eV" value="120.505737007499"/>
      <D unit="g/cm3" value="2.23"/>
      <fraction n="0.37677716758196" ref="Silicon"/>
      <fraction n="0.540476709287037" ref="Oxygen"/>
      <fraction n="0.040370583165757" ref="Boron"/>
      <fraction n="0.0296740884156179" ref="Sodium"/>
      <fraction n="0.0127014515496273" ref="Aluminum"/>
    </material>
    <material name="MRDSteel" state="solid">
      <T unit="K" value="293.15"/>
      <MEE unit="eV" value="282.156966376465"/>
      <D unit="g/cm3" value="7.8"/>
      <fraction n="0.01" ref="Carbon"/>
      <fraction n="0.99" ref="Iron"/>
    </material>
    <material Z="13" name="Aluminium" state="solid">
      <T unit="K" value="293.15"/>
      <MEE unit="eV" value="166"/>
      <D unit="g/cm3" value="2.7"/>
      <atom unit="g/mole" value="26.98"/>
    </material>
    <material name="Vacuum" state="gas">
      <T unit="K" value="0.1"/>
      <P unit="pascal" value="1e-19"/>
      <MEE unit="eV" value="19.2"/>
      <D unit="g/cm3" value="1e-25"/>
      <fraction n="1" ref="H"/>
    </material>
${G4_Ar}
  </materials>
  <solids>
    <box lunit="mm" name="ROOF_S" x="7823.2" y="6.35" z="5689.6"/>
    <box lunit="mm" name="ROOFC_S" x="7823.2" y="457.2" z="5689.6"/>
    ${TARGON_LV}
    ${TDEWAR_LV}
    <tube aunit="deg" deltaphi="360" lunit="mm" name="TWATER_S" rmax="1519.24" rmin="0" startphi="0" z="3956.05"/>
    <tube aunit="deg" deltaphi="360" lunit="mm" name="TBODY_S" rmax="1524.0" rmin="0" startphi="0" z="3956.05"/>
    <tube aunit="deg" deltaphi="360" lunit="mm" name="TBASE_S" rmax="1549.4" rmin="0" startphi="0" z="6.35"/>
    <cone aunit="deg" deltaphi="360" lunit="mm" name="TOCONE_S" rmax1="1524.0" rmax2="0" rmin1="0" rmin2="0" startphi="0" z="228.6"/>
    <cone aunit="deg" deltaphi="360" lunit="mm" name="TICONE_S" rmax1="1495.03" rmax2="0" rmin1="0" rmin2="0" startphi="0" z="223.771807241576"/>
    <subtraction name="TCONE_S">
      <first ref="TOCONE_S"/>
      <second ref="TICONE_S"/>
      <position name="TCONE_S_pos" unit="mm" x="0" y="0" z="-2.41409637921211"/>
    </subtraction>
    <tube aunit="deg" deltaphi="360" lunit="mm" name="FAKEROD_S" rmax="10" rmin="0" startphi="0" z="2133.6"/>
    <box lunit="mm" name="EXP_HALL" x="7010.4" y="12344.4" z="4876.8"/>
    <box lunit="mm" name="BLDG_S" x="7823.2" y="13258.8" z="5689.6"/>
    <box lunit="mm" name="TILLBASE_S" x="39999.98" y="26248.38" z="39999.98"/>
    <box lunit="mm" name="TILLHOLE_S" x="7825.2" y="8840.2" z="5691.6"/>
    <subtraction name="TILL_S">
      <first ref="TILLBASE_S"/>
      <second ref="TILLHOLE_S"/>
      <position name="TILL_S_pos" unit="mm" x="-431.799999999999" y="8704.1" z="2438.4"/>
    </subtraction>
    <box lunit="mm" name="WORLD_S" x="40000" y="40000" z="40000"/>
    <box lunit="mm" name="WORLD2_S" x="3000" y="7000" z="5000"/>
    <box lunit="mm" name="scintHpaddle0x34dbb10" x="200" y="1472" z="6"/>
    <box lunit="mm" name="scintVpaddle0x34dbcf0" x="200" y="1302" z="6"/>
    <trd lunit="mm" name="mrdScintTap_box0x34dbd80" x1="200" x2="171" y1="6" y2="6" z="78"/>
    <trd lunit="mm" name="mrdLG_box0x34dbe20" x1="171" x2="50.8" y1="6" y2="6" z="333"/>
    <box lunit="mm" name="steelPlate0x34dbf50" x="3050" y="2740" z="50"/>
    <box lunit="mm" name="outer_Box0x34dbfe0" x="3200" y="2890" z="38.1"/>
    <box lunit="mm" name="inner_Box0x34dc070" x="982.8" y="879.466666666667" z="38.1"/>
    <subtraction name="aluStruct0x354f8e0">
      <first ref="outer_Box0x34dbfe0"/>
      <second ref="inner_Box0x34dc070"/>
      <position name="aluStruct0x354f8e0_pos" unit="mm" x="1008.2" y="904.866666666667" z="0"/>
    </subtraction>
    <subtraction name="aluStruct0x354faf0">
      <first ref="aluStruct0x354f8e0"/>
      <second ref="inner_Box0x34dc070"/>
      <position name="aluStruct0x354faf0_pos" unit="mm" x="-1008.2" y="-904.866666666667" z="0"/>
    </subtraction>
    <subtraction name="aluStruct0x354fd00">
      <first ref="aluStruct0x354faf0"/>
      <second ref="inner_Box0x34dc070"/>
      <position name="aluStruct0x354fd00_pos" unit="mm" x="0" y="-904.866666666667" z="0"/>
    </subtraction>
    <subtraction name="aluStruct0x354ff10">
      <first ref="aluStruct0x354fd00"/>
      <second ref="inner_Box0x34dc070"/>
      <position name="aluStruct0x354ff10_pos" unit="mm" x="1008.2" y="-904.866666666667" z="0"/>
    </subtraction>
    <subtraction name="aluStruct0x3550120">
      <first ref="aluStruct0x354ff10"/>
      <second ref="inner_Box0x34dc070"/>
      <position name="aluStruct0x3550120_pos" unit="mm" x="-1008.2" y="0" z="0"/>
    </subtraction>
    <subtraction name="aluStruct0x3550330">
      <first ref="aluStruct0x3550120"/>
      <second ref="inner_Box0x34dc070"/>
    </subtraction>
    <subtraction name="aluStruct0x3550540">
      <first ref="aluStruct0x3550330"/>
      <second ref="inner_Box0x34dc070"/>
      <position name="aluStruct0x3550540_pos" unit="mm" x="1008.2" y="0" z="0"/>
    </subtraction>
    <subtraction name="aluStruct0x3550750">
      <first ref="aluStruct0x3550540"/>
      <second ref="inner_Box0x34dc070"/>
      <position name="aluStruct0x3550750_pos" unit="mm" x="-1008.2" y="904.866666666667" z="0"/>
    </subtraction>
    <subtraction name="aluStruct0x3550960">
      <first ref="aluStruct0x3550750"/>
      <second ref="inner_Box0x34dc070"/>
      <position name="aluStruct0x3550960_pos" unit="mm" x="0" y="904.866666666667" z="0"/>
    </subtraction>
    <subtraction name="aluStruct0x3550b70">
      <first ref="aluStruct0x3550960"/>
      <second ref="inner_Box0x34dc070"/>
      <position name="aluStruct0x3550b70_pos" unit="mm" x="1008.2" y="904.866666666667" z="0"/>
    </subtraction>
    <box lunit="mm" name="totMRD0x34dc100" x="3782.56" y="3442.56" z="1390.9"/>
    <box lunit="mm" name="vetoPaddle_box0x34dc190" x="3200" y="305" z="20"/>
    <trd lunit="mm" name="vetoLG_box0x34dc2b0" x1="305" x2="100" y1="20" y2="20" z="500"/>
    <box lunit="mm" name="totVeto_box0x34dc350" x="4220.56" y="4214.9" z="207.2"/>
  </solids>
  <structure>
    <volume name="ROOF_LV">
      <materialref ref="Steel"/>
      <solidref ref="ROOF_S"/>
    </volume>
    <volume name="ROOFC_LV">
      <materialref ref="G4_AIR"/>
      <solidref ref="ROOFC_S"/>
      <physvol name="ROOF_PV">
        <volumeref ref="ROOF_LV"/>
        <position name="ROOF_PV_pos" unit="mm" x="0" y="-225.425" z="0"/>
      </physvol>
    </volume>
    <volume name="TARGON_LV">
      <materialref ref="$GDMLMATERIAL"/>
      <solidref ref="TARGON_S"/>
    </volume>
    <volume name="TDEWAR_LV">
      <materialref ref="TankSteel"/>
      <solidref ref="TDEWAR_S"/>
      <physvol name="TARGON_PV">
        <volumeref ref="TARGON_LV"/>
      </physvol>
    </volume>
    <volume name="TWATER_LV">
      <materialref ref="TankWater"/>
      <solidref ref="TWATER_S"/>
      <physvol name="TDEWUR_PV">
        <volumeref ref="TDEWAR_LV"/>
        <position name="TDEWAR_PV_pos" unit="mm" x="0" y="$(echo 1519.24 - 600 - 500 | bc)" z="0"/>
      </physvol>
    </volume>
    <volume name="TBODY_LV">
      <materialref ref="TankSteel"/>
      <solidref ref="TBODY_S"/>
      <physvol name="TWATER_PV">
        <volumeref ref="TWATER_LV"/>
      </physvol>
    </volume>
    <volume name="TBASE_LV">
      <materialref ref="TankSteel"/>
      <solidref ref="TBASE_S"/>
    </volume>
    <volume name="TCONE_LV">
      <materialref ref="TankSteel"/>
      <solidref ref="TCONE_S"/>
    </volume>
    <volume name="FAKEROD_LV">
      <materialref ref="TankSteel"/>
      <solidref ref="FAKEROD_S"/>
    </volume>
    <volume name="vpaddle_log0x34dd440">
      <materialref ref="Scinti"/>
      <solidref ref="scintHpaddle0x34dbb10"/>
    </volume>
    <volume name="hpaddle_log0x34dd4f0">
      <materialref ref="Scinti"/>
      <solidref ref="scintVpaddle0x34dbcf0"/>
    </volume>
    <volume name="taper_log0x34e2760">
      <materialref ref="Scinti"/>
      <solidref ref="mrdScintTap_box0x34dbd80"/>
    </volume>
    <volume name="lg_log0x34f7610">
      <materialref ref="Glass"/>
      <solidref ref="mrdLG_box0x34dbe20"/>
    </volume>
    <volume name="steel_log0x34eb960">
      <materialref ref="MRDSteel"/>
      <solidref ref="steelPlate0x34dbf50"/>
    </volume>
    <volume name="aluStruct0x3550db0">
      <materialref ref="Aluminium"/>
      <solidref ref="aluStruct0x3550b70"/>
    </volume>
    <volume name="totMRDlog0x34dd320">
      <materialref ref="Vacuum"/>
      <solidref ref="totMRD0x34dc100"/>
      <physvol name="paddle_phys0x34dd3a0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34dd3a0_pos" unit="mm" x="737.5" y="-1219.5" z="-586.65"/>
        <rotation name="paddle_phys0x34dd3a0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34dd5c0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34dd5c0_pos" unit="mm" x="-737.5" y="-1219.5" z="-586.65"/>
        <rotation name="paddle_phys0x34dd5c0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34dd650">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34dd650_pos" unit="mm" x="737.5" y="-1016.5" z="-586.65"/>
        <rotation name="paddle_phys0x34dd650_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol> <physvol name="paddle_phys0x34dd720">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34dd720_pos" unit="mm" x="-737.5" y="-1016.5" z="-586.65"/>
        <rotation name="paddle_phys0x34dd720_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34dd790">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34dd790_pos" unit="mm" x="737.5" y="-813.5" z="-586.65"/>
        <rotation name="paddle_phys0x34dd790_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34dd870">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34dd870_pos" unit="mm" x="-737.5" y="-813.5" z="-586.65"/>
        <rotation name="paddle_phys0x34dd870_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34dd8b0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34dd8b0_pos" unit="mm" x="737.5" y="-610.5" z="-586.65"/>
        <rotation name="paddle_phys0x34dd8b0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34dd920">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34dd920_pos" unit="mm" x="-737.5" y="-610.5" z="-586.65"/>
        <rotation name="paddle_phys0x34dd920_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34dd990">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34dd990_pos" unit="mm" x="737.5" y="-407.5" z="-586.65"/>
        <rotation name="paddle_phys0x34dd990_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34ddb20">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34ddb20_pos" unit="mm" x="-737.5" y="-407.5" z="-586.65"/>
        <rotation name="paddle_phys0x34ddb20_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34ddb90">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34ddb90_pos" unit="mm" x="737.5" y="-204.5" z="-586.65"/>
        <rotation name="paddle_phys0x34ddb90_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34ddc00">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34ddc00_pos" unit="mm" x="-737.5" y="-204.5" z="-586.65"/>
        <rotation name="paddle_phys0x34ddc00_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34ddc70">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34ddc70_pos" unit="mm" x="737.5" y="-1.5" z="-586.65"/>
        <rotation name="paddle_phys0x34ddc70_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34ddce0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34ddce0_pos" unit="mm" x="-737.5" y="-1.5" z="-586.65"/>
        <rotation name="paddle_phys0x34ddce0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34ddd50">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34ddd50_pos" unit="mm" x="737.5" y="201.5" z="-586.65"/>
        <rotation name="paddle_phys0x34ddd50_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34dddc0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34dddc0_pos" unit="mm" x="-737.5" y="201.5" z="-586.65"/>
        <rotation name="paddle_phys0x34dddc0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34dde30">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34dde30_pos" unit="mm" x="737.5" y="404.5" z="-586.65"/>
        <rotation name="paddle_phys0x34dde30_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34dda00">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34dda00_pos" unit="mm" x="-737.5" y="404.5" z="-586.65"/>
        <rotation name="paddle_phys0x34dda00_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34dda70">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34dda70_pos" unit="mm" x="737.5" y="607.5" z="-586.65"/>
        <rotation name="paddle_phys0x34dda70_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34de090">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34de090_pos" unit="mm" x="-737.5" y="607.5" z="-586.65"/>
        <rotation name="paddle_phys0x34de090_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34de100">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34de100_pos" unit="mm" x="737.5" y="810.5" z="-586.65"/>
        <rotation name="paddle_phys0x34de100_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34de170">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34de170_pos" unit="mm" x="-737.5" y="810.5" z="-586.65"/>
        <rotation name="paddle_phys0x34de170_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34de1e0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34de1e0_pos" unit="mm" x="737.5" y="1013.5" z="-586.65"/>
        <rotation name="paddle_phys0x34de1e0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34de250">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34de250_pos" unit="mm" x="-737.5" y="1013.5" z="-586.65"/>
        <rotation name="paddle_phys0x34de250_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34de2c0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34de2c0_pos" unit="mm" x="737.5" y="1216.5" z="-586.65"/>
        <rotation name="paddle_phys0x34de2c0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34de330">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34de330_pos" unit="mm" x="-737.5" y="1216.5" z="-586.65"/>
        <rotation name="paddle_phys0x34de330_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34de3a0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34de3a0_pos" unit="mm" x="-1422.5" y="652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34de410">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34de410_pos" unit="mm" x="-1422.5" y="-652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34de480">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34de480_pos" unit="mm" x="-1219.5" y="652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34de4f0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34de4f0_pos" unit="mm" x="-1219.5" y="-652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34de560">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34de560_pos" unit="mm" x="-1016.5" y="652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34de5d0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34de5d0_pos" unit="mm" x="-1016.5" y="-652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34de640">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34de640_pos" unit="mm" x="-813.5" y="652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34ddea0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34ddea0_pos" unit="mm" x="-813.5" y="-652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34ddf10">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34ddf10_pos" unit="mm" x="-610.5" y="652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34ddf80">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34ddf80_pos" unit="mm" x="-610.5" y="-652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34ddff0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34ddff0_pos" unit="mm" x="-407.5" y="652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34deaa0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34deaa0_pos" unit="mm" x="-407.5" y="-652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34deae0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34deae0_pos" unit="mm" x="-204.5" y="652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34deb50">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34deb50_pos" unit="mm" x="-204.5" y="-652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34debc0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34debc0_pos" unit="mm" x="-1.5" y="652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34dec30">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34dec30_pos" unit="mm" x="-1.5" y="-652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34deca0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34deca0_pos" unit="mm" x="201.5" y="652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34ded10">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34ded10_pos" unit="mm" x="201.5" y="-652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34ded80">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34ded80_pos" unit="mm" x="404.5" y="652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34dedf0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34dedf0_pos" unit="mm" x="404.5" y="-652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34dee60">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34dee60_pos" unit="mm" x="607.5" y="652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34deed0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34deed0_pos" unit="mm" x="607.5" y="-652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34def40">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34def40_pos" unit="mm" x="810.5" y="652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34defb0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34defb0_pos" unit="mm" x="810.5" y="-652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34df020">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34df020_pos" unit="mm" x="1013.5" y="652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34df090">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34df090_pos" unit="mm" x="1013.5" y="-652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34df100">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34df100_pos" unit="mm" x="1216.5" y="652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34dd800">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34dd800_pos" unit="mm" x="1216.5" y="-652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34da3d0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34da3d0_pos" unit="mm" x="1419.5" y="652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34da440">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34da440_pos" unit="mm" x="1419.5" y="-652.5" z="-465.55"/>
      </physvol>
      <physvol name="paddle_phys0x34da4b0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34da4b0_pos" unit="mm" x="737.5" y="-1219.5" z="-344.45"/>
        <rotation name="paddle_phys0x34da4b0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34da520">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34da520_pos" unit="mm" x="-737.5" y="-1219.5" z="-344.45"/>
        <rotation name="paddle_phys0x34da520_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34da590">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34da590_pos" unit="mm" x="737.5" y="-1016.5" z="-344.45"/>
        <rotation name="paddle_phys0x34da590_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34da600">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34da600_pos" unit="mm" x="-737.5" y="-1016.5" z="-344.45"/>
        <rotation name="paddle_phys0x34da600_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34da670">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34da670_pos" unit="mm" x="737.5" y="-813.5" z="-344.45"/>
        <rotation name="paddle_phys0x34da670_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34da6e0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34da6e0_pos" unit="mm" x="-737.5" y="-813.5" z="-344.45"/>
        <rotation name="paddle_phys0x34da6e0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34da750">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34da750_pos" unit="mm" x="737.5" y="-610.5" z="-344.45"/>
        <rotation name="paddle_phys0x34da750_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34da7c0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34da7c0_pos" unit="mm" x="-737.5" y="-610.5" z="-344.45"/>
        <rotation name="paddle_phys0x34da7c0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34da830">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34da830_pos" unit="mm" x="737.5" y="-407.5" z="-344.45"/>
        <rotation name="paddle_phys0x34da830_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34da8a0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34da8a0_pos" unit="mm" x="-737.5" y="-407.5" z="-344.45"/>
        <rotation name="paddle_phys0x34da8a0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34da910">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34da910_pos" unit="mm" x="737.5" y="-204.5" z="-344.45"/>
        <rotation name="paddle_phys0x34da910_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34da980">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34da980_pos" unit="mm" x="-737.5" y="-204.5" z="-344.45"/>
        <rotation name="paddle_phys0x34da980_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34de680">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34de680_pos" unit="mm" x="737.5" y="-1.5" z="-344.45"/>
        <rotation name="paddle_phys0x34de680_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34de6c0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34de6c0_pos" unit="mm" x="-737.5" y="-1.5" z="-344.45"/>
        <rotation name="paddle_phys0x34de6c0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34de730">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34de730_pos" unit="mm" x="737.5" y="201.5" z="-344.45"/>
        <rotation name="paddle_phys0x34de730_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34de7a0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34de7a0_pos" unit="mm" x="-737.5" y="201.5" z="-344.45"/>
        <rotation name="paddle_phys0x34de7a0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34de810">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34de810_pos" unit="mm" x="737.5" y="404.5" z="-344.45"/>
        <rotation name="paddle_phys0x34de810_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34de880">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34de880_pos" unit="mm" x="-737.5" y="404.5" z="-344.45"/>
        <rotation name="paddle_phys0x34de880_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34de8f0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34de8f0_pos" unit="mm" x="737.5" y="607.5" z="-344.45"/>
        <rotation name="paddle_phys0x34de8f0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34de960">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34de960_pos" unit="mm" x="-737.5" y="607.5" z="-344.45"/>
        <rotation name="paddle_phys0x34de960_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34de9d0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34de9d0_pos" unit="mm" x="737.5" y="810.5" z="-344.45"/>
        <rotation name="paddle_phys0x34de9d0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34dea40">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34dea40_pos" unit="mm" x="-737.5" y="810.5" z="-344.45"/>
        <rotation name="paddle_phys0x34dea40_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e0620">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e0620_pos" unit="mm" x="737.5" y="1013.5" z="-344.45"/>
        <rotation name="paddle_phys0x34e0620_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e0690">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e0690_pos" unit="mm" x="-737.5" y="1013.5" z="-344.45"/>
        <rotation name="paddle_phys0x34e0690_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e0700">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e0700_pos" unit="mm" x="737.5" y="1216.5" z="-344.45"/>
        <rotation name="paddle_phys0x34e0700_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e0770">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e0770_pos" unit="mm" x="-737.5" y="1216.5" z="-344.45"/>
        <rotation name="paddle_phys0x34e0770_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e07e0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e07e0_pos" unit="mm" x="-1422.5" y="652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e0850">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e0850_pos" unit="mm" x="-1422.5" y="-652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e08c0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e08c0_pos" unit="mm" x="-1219.5" y="652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e0930">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e0930_pos" unit="mm" x="-1219.5" y="-652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e09a0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e09a0_pos" unit="mm" x="-1016.5" y="652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e0a10">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e0a10_pos" unit="mm" x="-1016.5" y="-652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e0a80">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e0a80_pos" unit="mm" x="-813.5" y="652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e0af0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e0af0_pos" unit="mm" x="-813.5" y="-652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e0b60">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e0b60_pos" unit="mm" x="-610.5" y="652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e0bd0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e0bd0_pos" unit="mm" x="-610.5" y="-652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e0c40">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e0c40_pos" unit="mm" x="-407.5" y="652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e0cb0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e0cb0_pos" unit="mm" x="-407.5" y="-652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e0d20">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e0d20_pos" unit="mm" x="-204.5" y="652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e0d90">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e0d90_pos" unit="mm" x="-204.5" y="-652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e0e00">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e0e00_pos" unit="mm" x="-1.5" y="652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e0e70">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e0e70_pos" unit="mm" x="-1.5" y="-652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e0ee0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e0ee0_pos" unit="mm" x="201.5" y="652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e0f50">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e0f50_pos" unit="mm" x="201.5" y="-652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e0fc0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e0fc0_pos" unit="mm" x="404.5" y="652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e1030">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e1030_pos" unit="mm" x="404.5" y="-652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e10a0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e10a0_pos" unit="mm" x="607.5" y="652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e1110">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e1110_pos" unit="mm" x="607.5" y="-652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e1180">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e1180_pos" unit="mm" x="810.5" y="652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e11f0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e11f0_pos" unit="mm" x="810.5" y="-652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e1260">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e1260_pos" unit="mm" x="1013.5" y="652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e12d0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e12d0_pos" unit="mm" x="1013.5" y="-652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e1340">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e1340_pos" unit="mm" x="1216.5" y="652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e13b0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e13b0_pos" unit="mm" x="1216.5" y="-652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e1420">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e1420_pos" unit="mm" x="1419.5" y="652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e1490">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e1490_pos" unit="mm" x="1419.5" y="-652.5" z="-223.35"/>
      </physvol>
      <physvol name="paddle_phys0x34e1500">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e1500_pos" unit="mm" x="737.5" y="-1219.5" z="-102.25"/>
        <rotation name="paddle_phys0x34e1500_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e1570">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e1570_pos" unit="mm" x="-737.5" y="-1219.5" z="-102.25"/>
        <rotation name="paddle_phys0x34e1570_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e15e0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e15e0_pos" unit="mm" x="737.5" y="-1016.5" z="-102.25"/>
        <rotation name="paddle_phys0x34e15e0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e1650">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e1650_pos" unit="mm" x="-737.5" y="-1016.5" z="-102.25"/>
        <rotation name="paddle_phys0x34e1650_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e16c0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e16c0_pos" unit="mm" x="737.5" y="-813.5" z="-102.25"/>
        <rotation name="paddle_phys0x34e16c0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e1730">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e1730_pos" unit="mm" x="-737.5" y="-813.5" z="-102.25"/>
        <rotation name="paddle_phys0x34e1730_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e17a0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e17a0_pos" unit="mm" x="737.5" y="-610.5" z="-102.25"/>
        <rotation name="paddle_phys0x34e17a0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e1810">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e1810_pos" unit="mm" x="-737.5" y="-610.5" z="-102.25"/>
        <rotation name="paddle_phys0x34e1810_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e1880">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e1880_pos" unit="mm" x="737.5" y="-407.5" z="-102.25"/>
        <rotation name="paddle_phys0x34e1880_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e18f0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e18f0_pos" unit="mm" x="-737.5" y="-407.5" z="-102.25"/>
        <rotation name="paddle_phys0x34e18f0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e1960">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e1960_pos" unit="mm" x="737.5" y="-204.5" z="-102.25"/>
        <rotation name="paddle_phys0x34e1960_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e19d0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e19d0_pos" unit="mm" x="-737.5" y="-204.5" z="-102.25"/>
        <rotation name="paddle_phys0x34e19d0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e1a40">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e1a40_pos" unit="mm" x="737.5" y="-1.5" z="-102.25"/>
        <rotation name="paddle_phys0x34e1a40_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e1ab0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e1ab0_pos" unit="mm" x="-737.5" y="-1.5" z="-102.25"/>
        <rotation name="paddle_phys0x34e1ab0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e1b20">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e1b20_pos" unit="mm" x="737.5" y="201.5" z="-102.25"/>
        <rotation name="paddle_phys0x34e1b20_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e1b90">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e1b90_pos" unit="mm" x="-737.5" y="201.5" z="-102.25"/>
        <rotation name="paddle_phys0x34e1b90_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e1c00">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e1c00_pos" unit="mm" x="737.5" y="404.5" z="-102.25"/>
        <rotation name="paddle_phys0x34e1c00_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34dfe00">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34dfe00_pos" unit="mm" x="-737.5" y="404.5" z="-102.25"/>
        <rotation name="paddle_phys0x34dfe00_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34dfe70">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34dfe70_pos" unit="mm" x="737.5" y="607.5" z="-102.25"/>
        <rotation name="paddle_phys0x34dfe70_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34dfee0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34dfee0_pos" unit="mm" x="-737.5" y="607.5" z="-102.25"/>
        <rotation name="paddle_phys0x34dfee0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34dff50">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34dff50_pos" unit="mm" x="737.5" y="810.5" z="-102.25"/>
        <rotation name="paddle_phys0x34dff50_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34dffc0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34dffc0_pos" unit="mm" x="-737.5" y="810.5" z="-102.25"/>
        <rotation name="paddle_phys0x34dffc0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e0030">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e0030_pos" unit="mm" x="737.5" y="1013.5" z="-102.25"/>
        <rotation name="paddle_phys0x34e0030_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e00a0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e00a0_pos" unit="mm" x="-737.5" y="1013.5" z="-102.25"/>
        <rotation name="paddle_phys0x34e00a0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e0110">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e0110_pos" unit="mm" x="737.5" y="1216.5" z="-102.25"/>
        <rotation name="paddle_phys0x34e0110_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e0180">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e0180_pos" unit="mm" x="-737.5" y="1216.5" z="-102.25"/>
        <rotation name="paddle_phys0x34e0180_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e01f0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e01f0_pos" unit="mm" x="-1422.5" y="652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e0260">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e0260_pos" unit="mm" x="-1422.5" y="-652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e02d0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e02d0_pos" unit="mm" x="-1219.5" y="652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e0340">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e0340_pos" unit="mm" x="-1219.5" y="-652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e03b0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e03b0_pos" unit="mm" x="-1016.5" y="652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e0420">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e0420_pos" unit="mm" x="-1016.5" y="-652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e0490">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e0490_pos" unit="mm" x="-813.5" y="652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e0500">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e0500_pos" unit="mm" x="-813.5" y="-652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e0570">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e0570_pos" unit="mm" x="-610.5" y="652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e2c60">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e2c60_pos" unit="mm" x="-610.5" y="-652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e2cd0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e2cd0_pos" unit="mm" x="-407.5" y="652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e2d40">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e2d40_pos" unit="mm" x="-407.5" y="-652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e2db0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e2db0_pos" unit="mm" x="-204.5" y="652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e2e20">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e2e20_pos" unit="mm" x="-204.5" y="-652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e2e90">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e2e90_pos" unit="mm" x="-1.5" y="652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e2f00">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e2f00_pos" unit="mm" x="-1.5" y="-652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e2f70">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e2f70_pos" unit="mm" x="201.5" y="652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e2fe0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e2fe0_pos" unit="mm" x="201.5" y="-652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e3050">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e3050_pos" unit="mm" x="404.5" y="652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e30c0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e30c0_pos" unit="mm" x="404.5" y="-652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e3130">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e3130_pos" unit="mm" x="607.5" y="652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e31a0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e31a0_pos" unit="mm" x="607.5" y="-652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e3210">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e3210_pos" unit="mm" x="810.5" y="652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e3280">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e3280_pos" unit="mm" x="810.5" y="-652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e32f0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e32f0_pos" unit="mm" x="1013.5" y="652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e3360">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e3360_pos" unit="mm" x="1013.5" y="-652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e33d0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e33d0_pos" unit="mm" x="1216.5" y="652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e3440">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e3440_pos" unit="mm" x="1216.5" y="-652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e34b0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e34b0_pos" unit="mm" x="1419.5" y="652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e3520">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e3520_pos" unit="mm" x="1419.5" y="-652.5" z="18.85"/>
      </physvol>
      <physvol name="paddle_phys0x34e3590">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e3590_pos" unit="mm" x="737.5" y="-1219.5" z="139.95"/>
        <rotation name="paddle_phys0x34e3590_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e3600">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e3600_pos" unit="mm" x="-737.5" y="-1219.5" z="139.95"/>
        <rotation name="paddle_phys0x34e3600_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e3670">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e3670_pos" unit="mm" x="737.5" y="-1016.5" z="139.95"/>
        <rotation name="paddle_phys0x34e3670_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e36e0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e36e0_pos" unit="mm" x="-737.5" y="-1016.5" z="139.95"/>
        <rotation name="paddle_phys0x34e36e0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e3750">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e3750_pos" unit="mm" x="737.5" y="-813.5" z="139.95"/>
        <rotation name="paddle_phys0x34e3750_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e37c0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e37c0_pos" unit="mm" x="-737.5" y="-813.5" z="139.95"/>
        <rotation name="paddle_phys0x34e37c0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e3830">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e3830_pos" unit="mm" x="737.5" y="-610.5" z="139.95"/>
        <rotation name="paddle_phys0x34e3830_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e38a0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e38a0_pos" unit="mm" x="-737.5" y="-610.5" z="139.95"/>
        <rotation name="paddle_phys0x34e38a0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e3910">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e3910_pos" unit="mm" x="737.5" y="-407.5" z="139.95"/>
        <rotation name="paddle_phys0x34e3910_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e3980">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e3980_pos" unit="mm" x="-737.5" y="-407.5" z="139.95"/>
        <rotation name="paddle_phys0x34e3980_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e39f0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e39f0_pos" unit="mm" x="737.5" y="-204.5" z="139.95"/>
        <rotation name="paddle_phys0x34e39f0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e3a60">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e3a60_pos" unit="mm" x="-737.5" y="-204.5" z="139.95"/>
        <rotation name="paddle_phys0x34e3a60_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e3ad0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e3ad0_pos" unit="mm" x="737.5" y="-1.5" z="139.95"/>
        <rotation name="paddle_phys0x34e3ad0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e3b40">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e3b40_pos" unit="mm" x="-737.5" y="-1.5" z="139.95"/>
        <rotation name="paddle_phys0x34e3b40_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e3bb0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e3bb0_pos" unit="mm" x="737.5" y="201.5" z="139.95"/>
        <rotation name="paddle_phys0x34e3bb0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e3c20">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e3c20_pos" unit="mm" x="-737.5" y="201.5" z="139.95"/>
        <rotation name="paddle_phys0x34e3c20_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e3c90">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e3c90_pos" unit="mm" x="737.5" y="404.5" z="139.95"/>
        <rotation name="paddle_phys0x34e3c90_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e3d00">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e3d00_pos" unit="mm" x="-737.5" y="404.5" z="139.95"/>
        <rotation name="paddle_phys0x34e3d00_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e3d70">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e3d70_pos" unit="mm" x="737.5" y="607.5" z="139.95"/>
        <rotation name="paddle_phys0x34e3d70_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e3de0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e3de0_pos" unit="mm" x="-737.5" y="607.5" z="139.95"/>
        <rotation name="paddle_phys0x34e3de0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e3e50">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e3e50_pos" unit="mm" x="737.5" y="810.5" z="139.95"/>
        <rotation name="paddle_phys0x34e3e50_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e3ec0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e3ec0_pos" unit="mm" x="-737.5" y="810.5" z="139.95"/>
        <rotation name="paddle_phys0x34e3ec0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e3f30">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e3f30_pos" unit="mm" x="737.5" y="1013.5" z="139.95"/>
        <rotation name="paddle_phys0x34e3f30_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e3fa0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e3fa0_pos" unit="mm" x="-737.5" y="1013.5" z="139.95"/>
        <rotation name="paddle_phys0x34e3fa0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e4010">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e4010_pos" unit="mm" x="737.5" y="1216.5" z="139.95"/>
        <rotation name="paddle_phys0x34e4010_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e4080">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e4080_pos" unit="mm" x="-737.5" y="1216.5" z="139.95"/>
        <rotation name="paddle_phys0x34e4080_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e40f0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e40f0_pos" unit="mm" x="-1422.5" y="652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e4160">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e4160_pos" unit="mm" x="-1422.5" y="-652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e41d0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e41d0_pos" unit="mm" x="-1219.5" y="652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e4240">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e4240_pos" unit="mm" x="-1219.5" y="-652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e42b0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e42b0_pos" unit="mm" x="-1016.5" y="652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e4320">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e4320_pos" unit="mm" x="-1016.5" y="-652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e4390">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e4390_pos" unit="mm" x="-813.5" y="652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e4400">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e4400_pos" unit="mm" x="-813.5" y="-652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e4470">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e4470_pos" unit="mm" x="-610.5" y="652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e44e0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e44e0_pos" unit="mm" x="-610.5" y="-652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e4550">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e4550_pos" unit="mm" x="-407.5" y="652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e45c0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e45c0_pos" unit="mm" x="-407.5" y="-652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e4630">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e4630_pos" unit="mm" x="-204.5" y="652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e46a0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e46a0_pos" unit="mm" x="-204.5" y="-652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e4710">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e4710_pos" unit="mm" x="-1.5" y="652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e4780">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e4780_pos" unit="mm" x="-1.5" y="-652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e47f0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e47f0_pos" unit="mm" x="201.5" y="652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e4860">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e4860_pos" unit="mm" x="201.5" y="-652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e48d0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e48d0_pos" unit="mm" x="404.5" y="652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e4940">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e4940_pos" unit="mm" x="404.5" y="-652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e49b0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e49b0_pos" unit="mm" x="607.5" y="652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e4a20">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e4a20_pos" unit="mm" x="607.5" y="-652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e4a90">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e4a90_pos" unit="mm" x="810.5" y="652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e4b00">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e4b00_pos" unit="mm" x="810.5" y="-652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e4b70">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e4b70_pos" unit="mm" x="1013.5" y="652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e4be0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e4be0_pos" unit="mm" x="1013.5" y="-652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e4c50">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e4c50_pos" unit="mm" x="1216.5" y="652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e4cc0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e4cc0_pos" unit="mm" x="1216.5" y="-652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e4d30">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e4d30_pos" unit="mm" x="1419.5" y="652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e4da0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e4da0_pos" unit="mm" x="1419.5" y="-652.5" z="261.05"/>
      </physvol>
      <physvol name="paddle_phys0x34e4e10">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e4e10_pos" unit="mm" x="737.5" y="-1219.5" z="382.15"/>
        <rotation name="paddle_phys0x34e4e10_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e4e80">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e4e80_pos" unit="mm" x="-737.5" y="-1219.5" z="382.15"/>
        <rotation name="paddle_phys0x34e4e80_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e4ef0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e4ef0_pos" unit="mm" x="737.5" y="-1016.5" z="382.15"/>
        <rotation name="paddle_phys0x34e4ef0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e4f60">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e4f60_pos" unit="mm" x="-737.5" y="-1016.5" z="382.15"/>
        <rotation name="paddle_phys0x34e4f60_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e4fd0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e4fd0_pos" unit="mm" x="737.5" y="-813.5" z="382.15"/>
        <rotation name="paddle_phys0x34e4fd0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e5040">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e5040_pos" unit="mm" x="-737.5" y="-813.5" z="382.15"/>
        <rotation name="paddle_phys0x34e5040_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e50b0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e50b0_pos" unit="mm" x="737.5" y="-610.5" z="382.15"/>
        <rotation name="paddle_phys0x34e50b0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e5120">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e5120_pos" unit="mm" x="-737.5" y="-610.5" z="382.15"/>
        <rotation name="paddle_phys0x34e5120_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e5190">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e5190_pos" unit="mm" x="737.5" y="-407.5" z="382.15"/>
        <rotation name="paddle_phys0x34e5190_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e5200">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e5200_pos" unit="mm" x="-737.5" y="-407.5" z="382.15"/>
        <rotation name="paddle_phys0x34e5200_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e5270">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e5270_pos" unit="mm" x="737.5" y="-204.5" z="382.15"/>
        <rotation name="paddle_phys0x34e5270_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e52e0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e52e0_pos" unit="mm" x="-737.5" y="-204.5" z="382.15"/>
        <rotation name="paddle_phys0x34e52e0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e5350">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e5350_pos" unit="mm" x="737.5" y="-1.5" z="382.15"/>
        <rotation name="paddle_phys0x34e5350_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e53c0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e53c0_pos" unit="mm" x="-737.5" y="-1.5" z="382.15"/>
        <rotation name="paddle_phys0x34e53c0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e5430">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e5430_pos" unit="mm" x="737.5" y="201.5" z="382.15"/>
        <rotation name="paddle_phys0x34e5430_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e54a0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e54a0_pos" unit="mm" x="-737.5" y="201.5" z="382.15"/>
        <rotation name="paddle_phys0x34e54a0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e5510">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e5510_pos" unit="mm" x="737.5" y="404.5" z="382.15"/>
        <rotation name="paddle_phys0x34e5510_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e5580">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e5580_pos" unit="mm" x="-737.5" y="404.5" z="382.15"/>
        <rotation name="paddle_phys0x34e5580_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e55f0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e55f0_pos" unit="mm" x="737.5" y="607.5" z="382.15"/>
        <rotation name="paddle_phys0x34e55f0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e5660">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e5660_pos" unit="mm" x="-737.5" y="607.5" z="382.15"/>
        <rotation name="paddle_phys0x34e5660_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e56d0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e56d0_pos" unit="mm" x="737.5" y="810.5" z="382.15"/>
        <rotation name="paddle_phys0x34e56d0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e5740">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e5740_pos" unit="mm" x="-737.5" y="810.5" z="382.15"/>
        <rotation name="paddle_phys0x34e5740_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e57b0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e57b0_pos" unit="mm" x="737.5" y="1013.5" z="382.15"/>
        <rotation name="paddle_phys0x34e57b0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e5820">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e5820_pos" unit="mm" x="-737.5" y="1013.5" z="382.15"/>
        <rotation name="paddle_phys0x34e5820_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e5890">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e5890_pos" unit="mm" x="737.5" y="1216.5" z="382.15"/>
        <rotation name="paddle_phys0x34e5890_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e5900">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e5900_pos" unit="mm" x="-737.5" y="1216.5" z="382.15"/>
        <rotation name="paddle_phys0x34e5900_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e5970">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e5970_pos" unit="mm" x="-1422.5" y="652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34e59e0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e59e0_pos" unit="mm" x="-1422.5" y="-652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34e5a50">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34e5a50_pos" unit="mm" x="-1219.5" y="652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34df170">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34df170_pos" unit="mm" x="-1219.5" y="-652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34df1e0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34df1e0_pos" unit="mm" x="-1016.5" y="652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34df250">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34df250_pos" unit="mm" x="-1016.5" y="-652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34df2c0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34df2c0_pos" unit="mm" x="-813.5" y="652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34df330">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34df330_pos" unit="mm" x="-813.5" y="-652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34df3a0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34df3a0_pos" unit="mm" x="-610.5" y="652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34df410">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34df410_pos" unit="mm" x="-610.5" y="-652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34df480">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34df480_pos" unit="mm" x="-407.5" y="652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34df4f0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34df4f0_pos" unit="mm" x="-407.5" y="-652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34df560">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34df560_pos" unit="mm" x="-204.5" y="652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34df5d0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34df5d0_pos" unit="mm" x="-204.5" y="-652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34df640">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34df640_pos" unit="mm" x="-1.5" y="652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34df6b0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34df6b0_pos" unit="mm" x="-1.5" y="-652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34df720">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34df720_pos" unit="mm" x="201.5" y="652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34df790">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34df790_pos" unit="mm" x="201.5" y="-652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34df800">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34df800_pos" unit="mm" x="404.5" y="652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34df870">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34df870_pos" unit="mm" x="404.5" y="-652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34df8e0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34df8e0_pos" unit="mm" x="607.5" y="652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34df950">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34df950_pos" unit="mm" x="607.5" y="-652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34df9c0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34df9c0_pos" unit="mm" x="810.5" y="652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34dfa30">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34dfa30_pos" unit="mm" x="810.5" y="-652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34dfaa0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34dfaa0_pos" unit="mm" x="1013.5" y="652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34dfb10">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34dfb10_pos" unit="mm" x="1013.5" y="-652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34dfb80">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34dfb80_pos" unit="mm" x="1216.5" y="652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34dfbf0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34dfbf0_pos" unit="mm" x="1216.5" y="-652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34dfc60">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34dfc60_pos" unit="mm" x="1419.5" y="652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34dfcd0">
        <volumeref ref="hpaddle_log0x34dd4f0"/>
        <position name="paddle_phys0x34dfcd0_pos" unit="mm" x="1419.5" y="-652.5" z="503.25"/>
      </physvol>
      <physvol name="paddle_phys0x34dfd40">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34dfd40_pos" unit="mm" x="737.5" y="-1219.5" z="624.35"/>
        <rotation name="paddle_phys0x34dfd40_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e1c40">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e1c40_pos" unit="mm" x="-737.5" y="-1219.5" z="624.35"/>
        <rotation name="paddle_phys0x34e1c40_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e1cb0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e1cb0_pos" unit="mm" x="737.5" y="-1016.5" z="624.35"/>
        <rotation name="paddle_phys0x34e1cb0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e1d20">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e1d20_pos" unit="mm" x="-737.5" y="-1016.5" z="624.35"/>
        <rotation name="paddle_phys0x34e1d20_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e1d90">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e1d90_pos" unit="mm" x="737.5" y="-813.5" z="624.35"/>
        <rotation name="paddle_phys0x34e1d90_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e1e00">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e1e00_pos" unit="mm" x="-737.5" y="-813.5" z="624.35"/>
        <rotation name="paddle_phys0x34e1e00_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e1e70">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e1e70_pos" unit="mm" x="737.5" y="-610.5" z="624.35"/>
        <rotation name="paddle_phys0x34e1e70_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e1ee0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e1ee0_pos" unit="mm" x="-737.5" y="-610.5" z="624.35"/>
        <rotation name="paddle_phys0x34e1ee0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e1f50">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e1f50_pos" unit="mm" x="737.5" y="-407.5" z="624.35"/>
        <rotation name="paddle_phys0x34e1f50_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e1fc0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e1fc0_pos" unit="mm" x="-737.5" y="-407.5" z="624.35"/>
        <rotation name="paddle_phys0x34e1fc0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e2030">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e2030_pos" unit="mm" x="737.5" y="-204.5" z="624.35"/>
        <rotation name="paddle_phys0x34e2030_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e20a0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e20a0_pos" unit="mm" x="-737.5" y="-204.5" z="624.35"/>
        <rotation name="paddle_phys0x34e20a0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e2110">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e2110_pos" unit="mm" x="737.5" y="-1.5" z="624.35"/>
        <rotation name="paddle_phys0x34e2110_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e2180">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e2180_pos" unit="mm" x="-737.5" y="-1.5" z="624.35"/>
        <rotation name="paddle_phys0x34e2180_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e21f0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e21f0_pos" unit="mm" x="737.5" y="201.5" z="624.35"/>
        <rotation name="paddle_phys0x34e21f0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e2260">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e2260_pos" unit="mm" x="-737.5" y="201.5" z="624.35"/>
        <rotation name="paddle_phys0x34e2260_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e22d0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e22d0_pos" unit="mm" x="737.5" y="404.5" z="624.35"/>
        <rotation name="paddle_phys0x34e22d0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e2340">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e2340_pos" unit="mm" x="-737.5" y="404.5" z="624.35"/>
        <rotation name="paddle_phys0x34e2340_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e23b0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e23b0_pos" unit="mm" x="737.5" y="607.5" z="624.35"/>
        <rotation name="paddle_phys0x34e23b0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e2420">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e2420_pos" unit="mm" x="-737.5" y="607.5" z="624.35"/>
        <rotation name="paddle_phys0x34e2420_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e2490">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e2490_pos" unit="mm" x="737.5" y="810.5" z="624.35"/>
        <rotation name="paddle_phys0x34e2490_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e2500">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e2500_pos" unit="mm" x="-737.5" y="810.5" z="624.35"/>
        <rotation name="paddle_phys0x34e2500_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e2570">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e2570_pos" unit="mm" x="737.5" y="1013.5" z="624.35"/>
        <rotation name="paddle_phys0x34e2570_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e25e0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e25e0_pos" unit="mm" x="-737.5" y="1013.5" z="624.35"/>
        <rotation name="paddle_phys0x34e25e0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e2650">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e2650_pos" unit="mm" x="737.5" y="1216.5" z="624.35"/>
        <rotation name="paddle_phys0x34e2650_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="paddle_phys0x34e26c0">
        <volumeref ref="vpaddle_log0x34dd440"/>
        <position name="paddle_phys0x34e26c0_pos" unit="mm" x="-737.5" y="1216.5" z="624.35"/>
        <rotation name="paddle_phys0x34e26c0_rot" unit="deg" x="0" y="0" z="-90"/>
      </physvol>
      <physvol name="taper_phys0x34e27e0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e27e0_pos" unit="mm" x="1512.5" y="-1219.5" z="-586.65"/>
        <rotation name="taper_phys0x34e27e0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e2850">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e2850_pos" unit="mm" x="-1512.5" y="-1219.5" z="-586.65"/>
        <rotation name="taper_phys0x34e2850_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e28c0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e28c0_pos" unit="mm" x="1512.5" y="-1016.5" z="-586.65"/>
        <rotation name="taper_phys0x34e28c0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e2960">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e2960_pos" unit="mm" x="-1512.5" y="-1016.5" z="-586.65"/>
        <rotation name="taper_phys0x34e2960_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e29d0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e29d0_pos" unit="mm" x="1512.5" y="-813.5" z="-586.65"/>
        <rotation name="taper_phys0x34e29d0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e2a60">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e2a60_pos" unit="mm" x="-1512.5" y="-813.5" z="-586.65"/>
        <rotation name="taper_phys0x34e2a60_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e2ad0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e2ad0_pos" unit="mm" x="1512.5" y="-610.5" z="-586.65"/>
        <rotation name="taper_phys0x34e2ad0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e2b40">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e2b40_pos" unit="mm" x="-1512.5" y="-610.5" z="-586.65"/>
        <rotation name="taper_phys0x34e2b40_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e2bb0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e2bb0_pos" unit="mm" x="1512.5" y="-407.5" z="-586.65"/>
        <rotation name="taper_phys0x34e2bb0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e2c20">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e2c20_pos" unit="mm" x="-1512.5" y="-407.5" z="-586.65"/>
        <rotation name="taper_phys0x34e2c20_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e9480">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e9480_pos" unit="mm" x="1512.5" y="-204.5" z="-586.65"/>
        <rotation name="taper_phys0x34e9480_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e94f0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e94f0_pos" unit="mm" x="-1512.5" y="-204.5" z="-586.65"/>
        <rotation name="taper_phys0x34e94f0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e9560">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e9560_pos" unit="mm" x="1512.5" y="-1.5" z="-586.65"/>
        <rotation name="taper_phys0x34e9560_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e95d0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e95d0_pos" unit="mm" x="-1512.5" y="-1.5" z="-586.65"/>
        <rotation name="taper_phys0x34e95d0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e9640">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e9640_pos" unit="mm" x="1512.5" y="201.5" z="-586.65"/>
        <rotation name="taper_phys0x34e9640_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e96b0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e96b0_pos" unit="mm" x="-1512.5" y="201.5" z="-586.65"/>
        <rotation name="taper_phys0x34e96b0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e9720">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e9720_pos" unit="mm" x="1512.5" y="404.5" z="-586.65"/>
        <rotation name="taper_phys0x34e9720_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e93f0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e93f0_pos" unit="mm" x="-1512.5" y="404.5" z="-586.65"/>
        <rotation name="taper_phys0x34e93f0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e98a0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e98a0_pos" unit="mm" x="1512.5" y="607.5" z="-586.65"/>
        <rotation name="taper_phys0x34e98a0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e9910">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e9910_pos" unit="mm" x="-1512.5" y="607.5" z="-586.65"/>
        <rotation name="taper_phys0x34e9910_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e9980">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e9980_pos" unit="mm" x="1512.5" y="810.5" z="-586.65"/>
        <rotation name="taper_phys0x34e9980_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e99f0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e99f0_pos" unit="mm" x="-1512.5" y="810.5" z="-586.65"/>
        <rotation name="taper_phys0x34e99f0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e9a60">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e9a60_pos" unit="mm" x="1512.5" y="1013.5" z="-586.65"/>
        <rotation name="taper_phys0x34e9a60_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e9ad0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e9ad0_pos" unit="mm" x="-1512.5" y="1013.5" z="-586.65"/>
        <rotation name="taper_phys0x34e9ad0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e9b40">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e9b40_pos" unit="mm" x="1512.5" y="1216.5" z="-586.65"/>
        <rotation name="taper_phys0x34e9b40_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e9bb0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e9bb0_pos" unit="mm" x="-1512.5" y="1216.5" z="-586.65"/>
        <rotation name="taper_phys0x34e9bb0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e9c20">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e9c20_pos" unit="mm" x="-1422.5" y="1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34e9c20_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34e9c90">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e9c90_pos" unit="mm" x="-1422.5" y="-1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34e9c90_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e9d00">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e9d00_pos" unit="mm" x="-1219.5" y="1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34e9d00_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34e9d70">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e9d70_pos" unit="mm" x="-1219.5" y="-1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34e9d70_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e9de0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e9de0_pos" unit="mm" x="-1016.5" y="1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34e9de0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34e9e50">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e9e50_pos" unit="mm" x="-1016.5" y="-1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34e9e50_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e9ec0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e9ec0_pos" unit="mm" x="-813.5" y="1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34e9ec0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34e9790">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e9790_pos" unit="mm" x="-813.5" y="-1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34e9790_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e9800">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e9800_pos" unit="mm" x="-610.5" y="1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34e9800_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34ea110">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ea110_pos" unit="mm" x="-610.5" y="-1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34ea110_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ea180">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ea180_pos" unit="mm" x="-407.5" y="1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34ea180_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34ea1f0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ea1f0_pos" unit="mm" x="-407.5" y="-1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34ea1f0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ea260">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ea260_pos" unit="mm" x="-204.5" y="1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34ea260_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34ea2d0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ea2d0_pos" unit="mm" x="-204.5" y="-1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34ea2d0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ea340">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ea340_pos" unit="mm" x="-1.5" y="1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34ea340_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34ea3b0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ea3b0_pos" unit="mm" x="-1.5" y="-1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34ea3b0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ea420">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ea420_pos" unit="mm" x="201.5" y="1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34ea420_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34ea490">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ea490_pos" unit="mm" x="201.5" y="-1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34ea490_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ea500">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ea500_pos" unit="mm" x="404.5" y="1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34ea500_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34ea570">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ea570_pos" unit="mm" x="404.5" y="-1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34ea570_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ea5e0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ea5e0_pos" unit="mm" x="607.5" y="1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34ea5e0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34ea650">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ea650_pos" unit="mm" x="607.5" y="-1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34ea650_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ea6c0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ea6c0_pos" unit="mm" x="810.5" y="1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34ea6c0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34ea730">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ea730_pos" unit="mm" x="810.5" y="-1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34ea730_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ea7a0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ea7a0_pos" unit="mm" x="1013.5" y="1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34ea7a0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34ea810">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ea810_pos" unit="mm" x="1013.5" y="-1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34ea810_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ea880">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ea880_pos" unit="mm" x="1216.5" y="1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34ea880_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34ea8f0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ea8f0_pos" unit="mm" x="1216.5" y="-1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34ea8f0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ea960">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ea960_pos" unit="mm" x="1419.5" y="1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34ea960_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34ea9d0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ea9d0_pos" unit="mm" x="1419.5" y="-1342.5" z="-465.55"/>
        <rotation name="taper_phys0x34ea9d0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34eaa40">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34eaa40_pos" unit="mm" x="1512.5" y="-1219.5" z="-344.45"/>
        <rotation name="taper_phys0x34eaa40_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34eaab0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34eaab0_pos" unit="mm" x="-1512.5" y="-1219.5" z="-344.45"/>
        <rotation name="taper_phys0x34eaab0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34eab20">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34eab20_pos" unit="mm" x="1512.5" y="-1016.5" z="-344.45"/>
        <rotation name="taper_phys0x34eab20_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a92a0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a92a0_pos" unit="mm" x="-1512.5" y="-1016.5" z="-344.45"/>
        <rotation name="taper_phys0x34a92a0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a9310">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a9310_pos" unit="mm" x="1512.5" y="-813.5" z="-344.45"/>
        <rotation name="taper_phys0x34a9310_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a9380">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a9380_pos" unit="mm" x="-1512.5" y="-813.5" z="-344.45"/>
        <rotation name="taper_phys0x34a9380_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a93f0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a93f0_pos" unit="mm" x="1512.5" y="-610.5" z="-344.45"/>
        <rotation name="taper_phys0x34a93f0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a9460">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a9460_pos" unit="mm" x="-1512.5" y="-610.5" z="-344.45"/>
        <rotation name="taper_phys0x34a9460_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a94d0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a94d0_pos" unit="mm" x="1512.5" y="-407.5" z="-344.45"/>
        <rotation name="taper_phys0x34a94d0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e9f30">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e9f30_pos" unit="mm" x="-1512.5" y="-407.5" z="-344.45"/>
        <rotation name="taper_phys0x34e9f30_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e9fa0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e9fa0_pos" unit="mm" x="1512.5" y="-204.5" z="-344.45"/>
        <rotation name="taper_phys0x34e9fa0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ea010">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ea010_pos" unit="mm" x="-1512.5" y="-204.5" z="-344.45"/>
        <rotation name="taper_phys0x34ea010_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ea080">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ea080_pos" unit="mm" x="1512.5" y="-1.5" z="-344.45"/>
        <rotation name="taper_phys0x34ea080_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a9920">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a9920_pos" unit="mm" x="-1512.5" y="-1.5" z="-344.45"/>
        <rotation name="taper_phys0x34a9920_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a9990">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a9990_pos" unit="mm" x="1512.5" y="201.5" z="-344.45"/>
        <rotation name="taper_phys0x34a9990_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a9a00">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a9a00_pos" unit="mm" x="-1512.5" y="201.5" z="-344.45"/>
        <rotation name="taper_phys0x34a9a00_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a9a70">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a9a70_pos" unit="mm" x="1512.5" y="404.5" z="-344.45"/>
        <rotation name="taper_phys0x34a9a70_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a9ae0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a9ae0_pos" unit="mm" x="-1512.5" y="404.5" z="-344.45"/>
        <rotation name="taper_phys0x34a9ae0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a9b50">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a9b50_pos" unit="mm" x="1512.5" y="607.5" z="-344.45"/>
        <rotation name="taper_phys0x34a9b50_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a9bc0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a9bc0_pos" unit="mm" x="-1512.5" y="607.5" z="-344.45"/>
        <rotation name="taper_phys0x34a9bc0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a9c30">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a9c30_pos" unit="mm" x="1512.5" y="810.5" z="-344.45"/>
        <rotation name="taper_phys0x34a9c30_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a9ca0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a9ca0_pos" unit="mm" x="-1512.5" y="810.5" z="-344.45"/>
        <rotation name="taper_phys0x34a9ca0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a9d10">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a9d10_pos" unit="mm" x="1512.5" y="1013.5" z="-344.45"/>
        <rotation name="taper_phys0x34a9d10_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a9d80">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a9d80_pos" unit="mm" x="-1512.5" y="1013.5" z="-344.45"/>
        <rotation name="taper_phys0x34a9d80_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a9df0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a9df0_pos" unit="mm" x="1512.5" y="1216.5" z="-344.45"/>
        <rotation name="taper_phys0x34a9df0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a9e60">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a9e60_pos" unit="mm" x="-1512.5" y="1216.5" z="-344.45"/>
        <rotation name="taper_phys0x34a9e60_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a9ed0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a9ed0_pos" unit="mm" x="-1422.5" y="1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34a9ed0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34a9f40">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a9f40_pos" unit="mm" x="-1422.5" y="-1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34a9f40_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a9fb0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a9fb0_pos" unit="mm" x="-1219.5" y="1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34a9fb0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34aa020">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aa020_pos" unit="mm" x="-1219.5" y="-1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34aa020_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34aa090">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aa090_pos" unit="mm" x="-1016.5" y="1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34aa090_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34aa100">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aa100_pos" unit="mm" x="-1016.5" y="-1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34aa100_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34aa170">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aa170_pos" unit="mm" x="-813.5" y="1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34aa170_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34aa1e0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aa1e0_pos" unit="mm" x="-813.5" y="-1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34aa1e0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34aa250">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aa250_pos" unit="mm" x="-610.5" y="1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34aa250_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34aa2c0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aa2c0_pos" unit="mm" x="-610.5" y="-1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34aa2c0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34aa330">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aa330_pos" unit="mm" x="-407.5" y="1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34aa330_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34aa3a0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aa3a0_pos" unit="mm" x="-407.5" y="-1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34aa3a0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34aa410">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aa410_pos" unit="mm" x="-204.5" y="1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34aa410_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34aa480">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aa480_pos" unit="mm" x="-204.5" y="-1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34aa480_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34aa4f0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aa4f0_pos" unit="mm" x="-1.5" y="1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34aa4f0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34aa560">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aa560_pos" unit="mm" x="-1.5" y="-1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34aa560_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34aa5d0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aa5d0_pos" unit="mm" x="201.5" y="1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34aa5d0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34aa640">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aa640_pos" unit="mm" x="201.5" y="-1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34aa640_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34aa6b0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aa6b0_pos" unit="mm" x="404.5" y="1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34aa6b0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34aa720">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aa720_pos" unit="mm" x="404.5" y="-1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34aa720_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34aa790">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aa790_pos" unit="mm" x="607.5" y="1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34aa790_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34aa800">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aa800_pos" unit="mm" x="607.5" y="-1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34aa800_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34aa870">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aa870_pos" unit="mm" x="810.5" y="1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34aa870_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34aa8e0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aa8e0_pos" unit="mm" x="810.5" y="-1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34aa8e0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34aa950">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aa950_pos" unit="mm" x="1013.5" y="1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34aa950_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34aa9c0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aa9c0_pos" unit="mm" x="1013.5" y="-1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34aa9c0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34aaa30">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aaa30_pos" unit="mm" x="1216.5" y="1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34aaa30_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34aaaa0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aaaa0_pos" unit="mm" x="1216.5" y="-1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34aaaa0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34aab10">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aab10_pos" unit="mm" x="1419.5" y="1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34aab10_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34aab80">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aab80_pos" unit="mm" x="1419.5" y="-1342.5" z="-223.35"/>
        <rotation name="taper_phys0x34aab80_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34aabf0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aabf0_pos" unit="mm" x="1512.5" y="-1219.5" z="-102.25"/>
        <rotation name="taper_phys0x34aabf0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34aac60">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aac60_pos" unit="mm" x="-1512.5" y="-1219.5" z="-102.25"/>
        <rotation name="taper_phys0x34aac60_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34aacd0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aacd0_pos" unit="mm" x="1512.5" y="-1016.5" z="-102.25"/>
        <rotation name="taper_phys0x34aacd0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34aad40">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aad40_pos" unit="mm" x="-1512.5" y="-1016.5" z="-102.25"/>
        <rotation name="taper_phys0x34aad40_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34aadb0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aadb0_pos" unit="mm" x="1512.5" y="-813.5" z="-102.25"/>
        <rotation name="taper_phys0x34aadb0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34aae20">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aae20_pos" unit="mm" x="-1512.5" y="-813.5" z="-102.25"/>
        <rotation name="taper_phys0x34aae20_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34aae90">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aae90_pos" unit="mm" x="1512.5" y="-610.5" z="-102.25"/>
        <rotation name="taper_phys0x34aae90_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34aaf00">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aaf00_pos" unit="mm" x="-1512.5" y="-610.5" z="-102.25"/>
        <rotation name="taper_phys0x34aaf00_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34aaf70">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aaf70_pos" unit="mm" x="1512.5" y="-407.5" z="-102.25"/>
        <rotation name="taper_phys0x34aaf70_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34aafe0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aafe0_pos" unit="mm" x="-1512.5" y="-407.5" z="-102.25"/>
        <rotation name="taper_phys0x34aafe0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ab050">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ab050_pos" unit="mm" x="1512.5" y="-204.5" z="-102.25"/>
        <rotation name="taper_phys0x34ab050_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ab0c0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ab0c0_pos" unit="mm" x="-1512.5" y="-204.5" z="-102.25"/>
        <rotation name="taper_phys0x34ab0c0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ab130">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ab130_pos" unit="mm" x="1512.5" y="-1.5" z="-102.25"/>
        <rotation name="taper_phys0x34ab130_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ab1a0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ab1a0_pos" unit="mm" x="-1512.5" y="-1.5" z="-102.25"/>
        <rotation name="taper_phys0x34ab1a0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ab210">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ab210_pos" unit="mm" x="1512.5" y="201.5" z="-102.25"/>
        <rotation name="taper_phys0x34ab210_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ab280">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ab280_pos" unit="mm" x="-1512.5" y="201.5" z="-102.25"/>
        <rotation name="taper_phys0x34ab280_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ab2f0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ab2f0_pos" unit="mm" x="1512.5" y="404.5" z="-102.25"/>
        <rotation name="taper_phys0x34ab2f0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a9540">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a9540_pos" unit="mm" x="-1512.5" y="404.5" z="-102.25"/>
        <rotation name="taper_phys0x34a9540_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a95b0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a95b0_pos" unit="mm" x="1512.5" y="607.5" z="-102.25"/>
        <rotation name="taper_phys0x34a95b0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a9620">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a9620_pos" unit="mm" x="-1512.5" y="607.5" z="-102.25"/>
        <rotation name="taper_phys0x34a9620_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a9690">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a9690_pos" unit="mm" x="1512.5" y="810.5" z="-102.25"/>
        <rotation name="taper_phys0x34a9690_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a9700">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a9700_pos" unit="mm" x="-1512.5" y="810.5" z="-102.25"/>
        <rotation name="taper_phys0x34a9700_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a9770">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a9770_pos" unit="mm" x="1512.5" y="1013.5" z="-102.25"/>
        <rotation name="taper_phys0x34a9770_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a97e0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a97e0_pos" unit="mm" x="-1512.5" y="1013.5" z="-102.25"/>
        <rotation name="taper_phys0x34a97e0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a9850">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a9850_pos" unit="mm" x="1512.5" y="1216.5" z="-102.25"/>
        <rotation name="taper_phys0x34a9850_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34a98c0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34a98c0_pos" unit="mm" x="-1512.5" y="1216.5" z="-102.25"/>
        <rotation name="taper_phys0x34a98c0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34abb70">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34abb70_pos" unit="mm" x="-1422.5" y="1342.5" z="18.85"/>
        <rotation name="taper_phys0x34abb70_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34abbe0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34abbe0_pos" unit="mm" x="-1422.5" y="-1342.5" z="18.85"/>
        <rotation name="taper_phys0x34abbe0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34abc50">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34abc50_pos" unit="mm" x="-1219.5" y="1342.5" z="18.85"/>
        <rotation name="taper_phys0x34abc50_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34abcc0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34abcc0_pos" unit="mm" x="-1219.5" y="-1342.5" z="18.85"/>
        <rotation name="taper_phys0x34abcc0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34abd30">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34abd30_pos" unit="mm" x="-1016.5" y="1342.5" z="18.85"/>
        <rotation name="taper_phys0x34abd30_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34abda0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34abda0_pos" unit="mm" x="-1016.5" y="-1342.5" z="18.85"/>
        <rotation name="taper_phys0x34abda0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34abe10">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34abe10_pos" unit="mm" x="-813.5" y="1342.5" z="18.85"/>
        <rotation name="taper_phys0x34abe10_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34abe80">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34abe80_pos" unit="mm" x="-813.5" y="-1342.5" z="18.85"/>
        <rotation name="taper_phys0x34abe80_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34abef0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34abef0_pos" unit="mm" x="-610.5" y="1342.5" z="18.85"/>
        <rotation name="taper_phys0x34abef0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34abf60">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34abf60_pos" unit="mm" x="-610.5" y="-1342.5" z="18.85"/>
        <rotation name="taper_phys0x34abf60_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34abfd0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34abfd0_pos" unit="mm" x="-407.5" y="1342.5" z="18.85"/>
        <rotation name="taper_phys0x34abfd0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34ac040">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ac040_pos" unit="mm" x="-407.5" y="-1342.5" z="18.85"/>
        <rotation name="taper_phys0x34ac040_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ac0b0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ac0b0_pos" unit="mm" x="-204.5" y="1342.5" z="18.85"/>
        <rotation name="taper_phys0x34ac0b0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34ac120">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ac120_pos" unit="mm" x="-204.5" y="-1342.5" z="18.85"/>
        <rotation name="taper_phys0x34ac120_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ac190">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ac190_pos" unit="mm" x="-1.5" y="1342.5" z="18.85"/>
        <rotation name="taper_phys0x34ac190_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34ac200">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ac200_pos" unit="mm" x="-1.5" y="-1342.5" z="18.85"/>
        <rotation name="taper_phys0x34ac200_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ac270">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ac270_pos" unit="mm" x="201.5" y="1342.5" z="18.85"/>
        <rotation name="taper_phys0x34ac270_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34ac2e0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ac2e0_pos" unit="mm" x="201.5" y="-1342.5" z="18.85"/>
        <rotation name="taper_phys0x34ac2e0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ac350">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ac350_pos" unit="mm" x="404.5" y="1342.5" z="18.85"/>
        <rotation name="taper_phys0x34ac350_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34ac3c0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ac3c0_pos" unit="mm" x="404.5" y="-1342.5" z="18.85"/>
        <rotation name="taper_phys0x34ac3c0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ac430">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ac430_pos" unit="mm" x="607.5" y="1342.5" z="18.85"/>
        <rotation name="taper_phys0x34ac430_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34ac4a0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ac4a0_pos" unit="mm" x="607.5" y="-1342.5" z="18.85"/>
        <rotation name="taper_phys0x34ac4a0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ac510">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ac510_pos" unit="mm" x="810.5" y="1342.5" z="18.85"/>
        <rotation name="taper_phys0x34ac510_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34ac580">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ac580_pos" unit="mm" x="810.5" y="-1342.5" z="18.85"/>
        <rotation name="taper_phys0x34ac580_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ac5f0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ac5f0_pos" unit="mm" x="1013.5" y="1342.5" z="18.85"/>
        <rotation name="taper_phys0x34ac5f0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34ac660">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ac660_pos" unit="mm" x="1013.5" y="-1342.5" z="18.85"/>
        <rotation name="taper_phys0x34ac660_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ac6d0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ac6d0_pos" unit="mm" x="1216.5" y="1342.5" z="18.85"/>
        <rotation name="taper_phys0x34ac6d0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34ac740">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ac740_pos" unit="mm" x="1216.5" y="-1342.5" z="18.85"/>
        <rotation name="taper_phys0x34ac740_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ac7b0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ac7b0_pos" unit="mm" x="1419.5" y="1342.5" z="18.85"/>
        <rotation name="taper_phys0x34ac7b0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34ac820">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ac820_pos" unit="mm" x="1419.5" y="-1342.5" z="18.85"/>
        <rotation name="taper_phys0x34ac820_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ac890">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ac890_pos" unit="mm" x="1512.5" y="-1219.5" z="139.95"/>
        <rotation name="taper_phys0x34ac890_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ac900">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ac900_pos" unit="mm" x="-1512.5" y="-1219.5" z="139.95"/>
        <rotation name="taper_phys0x34ac900_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ac970">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ac970_pos" unit="mm" x="1512.5" y="-1016.5" z="139.95"/>
        <rotation name="taper_phys0x34ac970_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ac9e0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ac9e0_pos" unit="mm" x="-1512.5" y="-1016.5" z="139.95"/>
        <rotation name="taper_phys0x34ac9e0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34aca50">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aca50_pos" unit="mm" x="1512.5" y="-813.5" z="139.95"/>
        <rotation name="taper_phys0x34aca50_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34acac0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34acac0_pos" unit="mm" x="-1512.5" y="-813.5" z="139.95"/>
        <rotation name="taper_phys0x34acac0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34acb30">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34acb30_pos" unit="mm" x="1512.5" y="-610.5" z="139.95"/>
        <rotation name="taper_phys0x34acb30_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34acba0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34acba0_pos" unit="mm" x="-1512.5" y="-610.5" z="139.95"/>
        <rotation name="taper_phys0x34acba0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34acc10">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34acc10_pos" unit="mm" x="1512.5" y="-407.5" z="139.95"/>
        <rotation name="taper_phys0x34acc10_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34acc80">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34acc80_pos" unit="mm" x="-1512.5" y="-407.5" z="139.95"/>
        <rotation name="taper_phys0x34acc80_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34accf0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34accf0_pos" unit="mm" x="1512.5" y="-204.5" z="139.95"/>
        <rotation name="taper_phys0x34accf0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34acd60">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34acd60_pos" unit="mm" x="-1512.5" y="-204.5" z="139.95"/>
        <rotation name="taper_phys0x34acd60_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34acdd0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34acdd0_pos" unit="mm" x="1512.5" y="-1.5" z="139.95"/>
        <rotation name="taper_phys0x34acdd0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ace40">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ace40_pos" unit="mm" x="-1512.5" y="-1.5" z="139.95"/>
        <rotation name="taper_phys0x34ace40_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34aceb0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aceb0_pos" unit="mm" x="1512.5" y="201.5" z="139.95"/>
        <rotation name="taper_phys0x34aceb0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34acf20">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34acf20_pos" unit="mm" x="-1512.5" y="201.5" z="139.95"/>
        <rotation name="taper_phys0x34acf20_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34acf90">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34acf90_pos" unit="mm" x="1512.5" y="404.5" z="139.95"/>
        <rotation name="taper_phys0x34acf90_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ad000">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ad000_pos" unit="mm" x="-1512.5" y="404.5" z="139.95"/>
        <rotation name="taper_phys0x34ad000_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ad070">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ad070_pos" unit="mm" x="1512.5" y="607.5" z="139.95"/>
        <rotation name="taper_phys0x34ad070_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ad0e0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ad0e0_pos" unit="mm" x="-1512.5" y="607.5" z="139.95"/>
        <rotation name="taper_phys0x34ad0e0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ad150">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ad150_pos" unit="mm" x="1512.5" y="810.5" z="139.95"/>
        <rotation name="taper_phys0x34ad150_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ad1c0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ad1c0_pos" unit="mm" x="-1512.5" y="810.5" z="139.95"/>
        <rotation name="taper_phys0x34ad1c0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ad230">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ad230_pos" unit="mm" x="1512.5" y="1013.5" z="139.95"/>
        <rotation name="taper_phys0x34ad230_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f2b70">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f2b70_pos" unit="mm" x="-1512.5" y="1013.5" z="139.95"/>
        <rotation name="taper_phys0x34f2b70_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f2be0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f2be0_pos" unit="mm" x="1512.5" y="1216.5" z="139.95"/>
        <rotation name="taper_phys0x34f2be0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f2c50">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f2c50_pos" unit="mm" x="-1512.5" y="1216.5" z="139.95"/>
        <rotation name="taper_phys0x34f2c50_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f2cc0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f2cc0_pos" unit="mm" x="-1422.5" y="1342.5" z="261.05"/>
        <rotation name="taper_phys0x34f2cc0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34f2d30">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f2d30_pos" unit="mm" x="-1422.5" y="-1342.5" z="261.05"/>
        <rotation name="taper_phys0x34f2d30_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f2da0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f2da0_pos" unit="mm" x="-1219.5" y="1342.5" z="261.05"/>
        <rotation name="taper_phys0x34f2da0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34f2e10">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f2e10_pos" unit="mm" x="-1219.5" y="-1342.5" z="261.05"/>
        <rotation name="taper_phys0x34f2e10_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f2e80">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f2e80_pos" unit="mm" x="-1016.5" y="1342.5" z="261.05"/>
        <rotation name="taper_phys0x34f2e80_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34f2ef0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f2ef0_pos" unit="mm" x="-1016.5" y="-1342.5" z="261.05"/>
        <rotation name="taper_phys0x34f2ef0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f2f60">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f2f60_pos" unit="mm" x="-813.5" y="1342.5" z="261.05"/>
        <rotation name="taper_phys0x34f2f60_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34f2fd0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f2fd0_pos" unit="mm" x="-813.5" y="-1342.5" z="261.05"/>
        <rotation name="taper_phys0x34f2fd0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f3040">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f3040_pos" unit="mm" x="-610.5" y="1342.5" z="261.05"/>
        <rotation name="taper_phys0x34f3040_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34f30b0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f30b0_pos" unit="mm" x="-610.5" y="-1342.5" z="261.05"/>
        <rotation name="taper_phys0x34f30b0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f3120">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f3120_pos" unit="mm" x="-407.5" y="1342.5" z="261.05"/>
        <rotation name="taper_phys0x34f3120_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34f3190">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f3190_pos" unit="mm" x="-407.5" y="-1342.5" z="261.05"/>
        <rotation name="taper_phys0x34f3190_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f3200">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f3200_pos" unit="mm" x="-204.5" y="1342.5" z="261.05"/>
        <rotation name="taper_phys0x34f3200_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34e73d0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e73d0_pos" unit="mm" x="-204.5" y="-1342.5" z="261.05"/>
        <rotation name="taper_phys0x34e73d0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e7440">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e7440_pos" unit="mm" x="-1.5" y="1342.5" z="261.05"/>
        <rotation name="taper_phys0x34e7440_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34e74b0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e74b0_pos" unit="mm" x="-1.5" y="-1342.5" z="261.05"/>
        <rotation name="taper_phys0x34e74b0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e7520">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e7520_pos" unit="mm" x="201.5" y="1342.5" z="261.05"/>
        <rotation name="taper_phys0x34e7520_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34e7590">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e7590_pos" unit="mm" x="201.5" y="-1342.5" z="261.05"/>
        <rotation name="taper_phys0x34e7590_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e7600">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e7600_pos" unit="mm" x="404.5" y="1342.5" z="261.05"/>
        <rotation name="taper_phys0x34e7600_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34e7670">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e7670_pos" unit="mm" x="404.5" y="-1342.5" z="261.05"/>
        <rotation name="taper_phys0x34e7670_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e76e0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e76e0_pos" unit="mm" x="607.5" y="1342.5" z="261.05"/>
        <rotation name="taper_phys0x34e76e0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34e7750">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e7750_pos" unit="mm" x="607.5" y="-1342.5" z="261.05"/>
        <rotation name="taper_phys0x34e7750_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e77c0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e77c0_pos" unit="mm" x="810.5" y="1342.5" z="261.05"/>
        <rotation name="taper_phys0x34e77c0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34e7830">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e7830_pos" unit="mm" x="810.5" y="-1342.5" z="261.05"/>
        <rotation name="taper_phys0x34e7830_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e78a0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e78a0_pos" unit="mm" x="1013.5" y="1342.5" z="261.05"/>
        <rotation name="taper_phys0x34e78a0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34e7910">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e7910_pos" unit="mm" x="1013.5" y="-1342.5" z="261.05"/>
        <rotation name="taper_phys0x34e7910_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e7980">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e7980_pos" unit="mm" x="1216.5" y="1342.5" z="261.05"/>
        <rotation name="taper_phys0x34e7980_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34e79f0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e79f0_pos" unit="mm" x="1216.5" y="-1342.5" z="261.05"/>
        <rotation name="taper_phys0x34e79f0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e7a60">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e7a60_pos" unit="mm" x="1419.5" y="1342.5" z="261.05"/>
        <rotation name="taper_phys0x34e7a60_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34e7ad0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e7ad0_pos" unit="mm" x="1419.5" y="-1342.5" z="261.05"/>
        <rotation name="taper_phys0x34e7ad0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e7b40">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e7b40_pos" unit="mm" x="1512.5" y="-1219.5" z="382.15"/>
        <rotation name="taper_phys0x34e7b40_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e7bb0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e7bb0_pos" unit="mm" x="-1512.5" y="-1219.5" z="382.15"/>
        <rotation name="taper_phys0x34e7bb0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e7c20">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e7c20_pos" unit="mm" x="1512.5" y="-1016.5" z="382.15"/>
        <rotation name="taper_phys0x34e7c20_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e7c90">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e7c90_pos" unit="mm" x="-1512.5" y="-1016.5" z="382.15"/>
        <rotation name="taper_phys0x34e7c90_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e7d00">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e7d00_pos" unit="mm" x="1512.5" y="-813.5" z="382.15"/>
        <rotation name="taper_phys0x34e7d00_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e7d70">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e7d70_pos" unit="mm" x="-1512.5" y="-813.5" z="382.15"/>
        <rotation name="taper_phys0x34e7d70_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e7de0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e7de0_pos" unit="mm" x="1512.5" y="-610.5" z="382.15"/>
        <rotation name="taper_phys0x34e7de0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e7e50">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e7e50_pos" unit="mm" x="-1512.5" y="-610.5" z="382.15"/>
        <rotation name="taper_phys0x34e7e50_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e7ec0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e7ec0_pos" unit="mm" x="1512.5" y="-407.5" z="382.15"/>
        <rotation name="taper_phys0x34e7ec0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e7f30">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e7f30_pos" unit="mm" x="-1512.5" y="-407.5" z="382.15"/>
        <rotation name="taper_phys0x34e7f30_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e7fa0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e7fa0_pos" unit="mm" x="1512.5" y="-204.5" z="382.15"/>
        <rotation name="taper_phys0x34e7fa0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e8010">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e8010_pos" unit="mm" x="-1512.5" y="-204.5" z="382.15"/>
        <rotation name="taper_phys0x34e8010_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e8080">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e8080_pos" unit="mm" x="1512.5" y="-1.5" z="382.15"/>
        <rotation name="taper_phys0x34e8080_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e80f0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e80f0_pos" unit="mm" x="-1512.5" y="-1.5" z="382.15"/>
        <rotation name="taper_phys0x34e80f0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e8160">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e8160_pos" unit="mm" x="1512.5" y="201.5" z="382.15"/>
        <rotation name="taper_phys0x34e8160_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e81d0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e81d0_pos" unit="mm" x="-1512.5" y="201.5" z="382.15"/>
        <rotation name="taper_phys0x34e81d0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e8240">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e8240_pos" unit="mm" x="1512.5" y="404.5" z="382.15"/>
        <rotation name="taper_phys0x34e8240_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e82b0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e82b0_pos" unit="mm" x="-1512.5" y="404.5" z="382.15"/>
        <rotation name="taper_phys0x34e82b0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34e8320">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34e8320_pos" unit="mm" x="1512.5" y="607.5" z="382.15"/>
        <rotation name="taper_phys0x34e8320_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f5250">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f5250_pos" unit="mm" x="-1512.5" y="607.5" z="382.15"/>
        <rotation name="taper_phys0x34f5250_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f52c0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f52c0_pos" unit="mm" x="1512.5" y="810.5" z="382.15"/>
        <rotation name="taper_phys0x34f52c0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f5330">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f5330_pos" unit="mm" x="-1512.5" y="810.5" z="382.15"/>
        <rotation name="taper_phys0x34f5330_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f53a0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f53a0_pos" unit="mm" x="1512.5" y="1013.5" z="382.15"/>
        <rotation name="taper_phys0x34f53a0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f5410">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f5410_pos" unit="mm" x="-1512.5" y="1013.5" z="382.15"/>
        <rotation name="taper_phys0x34f5410_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f5480">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f5480_pos" unit="mm" x="1512.5" y="1216.5" z="382.15"/>
        <rotation name="taper_phys0x34f5480_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f54f0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f54f0_pos" unit="mm" x="-1512.5" y="1216.5" z="382.15"/>
        <rotation name="taper_phys0x34f54f0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f5560">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f5560_pos" unit="mm" x="-1422.5" y="1342.5" z="503.25"/>
        <rotation name="taper_phys0x34f5560_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34f55d0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f55d0_pos" unit="mm" x="-1422.5" y="-1342.5" z="503.25"/>
        <rotation name="taper_phys0x34f55d0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f5640">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f5640_pos" unit="mm" x="-1219.5" y="1342.5" z="503.25"/>
        <rotation name="taper_phys0x34f5640_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34f56b0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f56b0_pos" unit="mm" x="-1219.5" y="-1342.5" z="503.25"/>
        <rotation name="taper_phys0x34f56b0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f5720">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f5720_pos" unit="mm" x="-1016.5" y="1342.5" z="503.25"/>
        <rotation name="taper_phys0x34f5720_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34f5790">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f5790_pos" unit="mm" x="-1016.5" y="-1342.5" z="503.25"/>
        <rotation name="taper_phys0x34f5790_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f5800">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f5800_pos" unit="mm" x="-813.5" y="1342.5" z="503.25"/>
        <rotation name="taper_phys0x34f5800_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34ab360">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ab360_pos" unit="mm" x="-813.5" y="-1342.5" z="503.25"/>
        <rotation name="taper_phys0x34ab360_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ab3d0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ab3d0_pos" unit="mm" x="-610.5" y="1342.5" z="503.25"/>
        <rotation name="taper_phys0x34ab3d0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34ab440">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ab440_pos" unit="mm" x="-610.5" y="-1342.5" z="503.25"/>
        <rotation name="taper_phys0x34ab440_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ab4b0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ab4b0_pos" unit="mm" x="-407.5" y="1342.5" z="503.25"/>
        <rotation name="taper_phys0x34ab4b0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34ab520">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ab520_pos" unit="mm" x="-407.5" y="-1342.5" z="503.25"/>
        <rotation name="taper_phys0x34ab520_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ab590">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ab590_pos" unit="mm" x="-204.5" y="1342.5" z="503.25"/>
        <rotation name="taper_phys0x34ab590_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34ab600">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ab600_pos" unit="mm" x="-204.5" y="-1342.5" z="503.25"/>
        <rotation name="taper_phys0x34ab600_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ab670">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ab670_pos" unit="mm" x="-1.5" y="1342.5" z="503.25"/>
        <rotation name="taper_phys0x34ab670_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34ab6e0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ab6e0_pos" unit="mm" x="-1.5" y="-1342.5" z="503.25"/>
        <rotation name="taper_phys0x34ab6e0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ab750">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ab750_pos" unit="mm" x="201.5" y="1342.5" z="503.25"/>
        <rotation name="taper_phys0x34ab750_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34ab7c0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ab7c0_pos" unit="mm" x="201.5" y="-1342.5" z="503.25"/>
        <rotation name="taper_phys0x34ab7c0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ab830">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ab830_pos" unit="mm" x="404.5" y="1342.5" z="503.25"/>
        <rotation name="taper_phys0x34ab830_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34ab8a0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ab8a0_pos" unit="mm" x="404.5" y="-1342.5" z="503.25"/>
        <rotation name="taper_phys0x34ab8a0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ab910">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ab910_pos" unit="mm" x="607.5" y="1342.5" z="503.25"/>
        <rotation name="taper_phys0x34ab910_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34ab980">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ab980_pos" unit="mm" x="607.5" y="-1342.5" z="503.25"/>
        <rotation name="taper_phys0x34ab980_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34ab9f0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34ab9f0_pos" unit="mm" x="810.5" y="1342.5" z="503.25"/>
        <rotation name="taper_phys0x34ab9f0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34aba60">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34aba60_pos" unit="mm" x="810.5" y="-1342.5" z="503.25"/>
        <rotation name="taper_phys0x34aba60_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34abad0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34abad0_pos" unit="mm" x="1013.5" y="1342.5" z="503.25"/>
        <rotation name="taper_phys0x34abad0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34f6850">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f6850_pos" unit="mm" x="1013.5" y="-1342.5" z="503.25"/>
        <rotation name="taper_phys0x34f6850_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f68c0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f68c0_pos" unit="mm" x="1216.5" y="1342.5" z="503.25"/>
        <rotation name="taper_phys0x34f68c0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34f6930">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f6930_pos" unit="mm" x="1216.5" y="-1342.5" z="503.25"/>
        <rotation name="taper_phys0x34f6930_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f69a0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f69a0_pos" unit="mm" x="1419.5" y="1342.5" z="503.25"/>
        <rotation name="taper_phys0x34f69a0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="taper_phys0x34f6a10">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f6a10_pos" unit="mm" x="1419.5" y="-1342.5" z="503.25"/>
        <rotation name="taper_phys0x34f6a10_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f6a80">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f6a80_pos" unit="mm" x="1512.5" y="-1219.5" z="624.35"/>
        <rotation name="taper_phys0x34f6a80_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f6af0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f6af0_pos" unit="mm" x="-1512.5" y="-1219.5" z="624.35"/>
        <rotation name="taper_phys0x34f6af0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f6b60">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f6b60_pos" unit="mm" x="1512.5" y="-1016.5" z="624.35"/>
        <rotation name="taper_phys0x34f6b60_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f6bd0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f6bd0_pos" unit="mm" x="-1512.5" y="-1016.5" z="624.35"/>
        <rotation name="taper_phys0x34f6bd0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f6c40">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f6c40_pos" unit="mm" x="1512.5" y="-813.5" z="624.35"/>
        <rotation name="taper_phys0x34f6c40_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f6cb0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f6cb0_pos" unit="mm" x="-1512.5" y="-813.5" z="624.35"/>
        <rotation name="taper_phys0x34f6cb0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f6d20">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f6d20_pos" unit="mm" x="1512.5" y="-610.5" z="624.35"/>
        <rotation name="taper_phys0x34f6d20_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f6d90">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f6d90_pos" unit="mm" x="-1512.5" y="-610.5" z="624.35"/>
        <rotation name="taper_phys0x34f6d90_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f6e00">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f6e00_pos" unit="mm" x="1512.5" y="-407.5" z="624.35"/>
        <rotation name="taper_phys0x34f6e00_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f6e70">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f6e70_pos" unit="mm" x="-1512.5" y="-407.5" z="624.35"/>
        <rotation name="taper_phys0x34f6e70_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f6ee0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f6ee0_pos" unit="mm" x="1512.5" y="-204.5" z="624.35"/>
        <rotation name="taper_phys0x34f6ee0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f6f50">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f6f50_pos" unit="mm" x="-1512.5" y="-204.5" z="624.35"/>
        <rotation name="taper_phys0x34f6f50_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f6fc0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f6fc0_pos" unit="mm" x="1512.5" y="-1.5" z="624.35"/>
        <rotation name="taper_phys0x34f6fc0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f7030">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f7030_pos" unit="mm" x="-1512.5" y="-1.5" z="624.35"/>
        <rotation name="taper_phys0x34f7030_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f70a0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f70a0_pos" unit="mm" x="1512.5" y="201.5" z="624.35"/>
        <rotation name="taper_phys0x34f70a0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f7110">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f7110_pos" unit="mm" x="-1512.5" y="201.5" z="624.35"/>
        <rotation name="taper_phys0x34f7110_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f7180">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f7180_pos" unit="mm" x="1512.5" y="404.5" z="624.35"/>
        <rotation name="taper_phys0x34f7180_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f71f0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f71f0_pos" unit="mm" x="-1512.5" y="404.5" z="624.35"/>
        <rotation name="taper_phys0x34f71f0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f7260">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f7260_pos" unit="mm" x="1512.5" y="607.5" z="624.35"/>
        <rotation name="taper_phys0x34f7260_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f72d0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f72d0_pos" unit="mm" x="-1512.5" y="607.5" z="624.35"/>
        <rotation name="taper_phys0x34f72d0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f7340">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f7340_pos" unit="mm" x="1512.5" y="810.5" z="624.35"/>
        <rotation name="taper_phys0x34f7340_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f73b0">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f73b0_pos" unit="mm" x="-1512.5" y="810.5" z="624.35"/>
        <rotation name="taper_phys0x34f73b0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f7420">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f7420_pos" unit="mm" x="1512.5" y="1013.5" z="624.35"/>
        <rotation name="taper_phys0x34f7420_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f7490">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f7490_pos" unit="mm" x="-1512.5" y="1013.5" z="624.35"/>
        <rotation name="taper_phys0x34f7490_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f7500">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f7500_pos" unit="mm" x="1512.5" y="1216.5" z="624.35"/>
        <rotation name="taper_phys0x34f7500_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="taper_phys0x34f7570">
        <volumeref ref="taper_log0x34e2760"/>
        <position name="taper_phys0x34f7570_pos" unit="mm" x="-1512.5" y="1216.5" z="624.35"/>
        <rotation name="taper_phys0x34f7570_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f7690">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f7690_pos" unit="mm" x="1718" y="-1219.5" z="-586.65"/>
        <rotation name="lg_phys0x34f7690_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f7700">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f7700_pos" unit="mm" x="-1718" y="-1219.5" z="-586.65"/>
        <rotation name="lg_phys0x34f7700_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f7770">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f7770_pos" unit="mm" x="1718" y="-1016.5" z="-586.65"/>
        <rotation name="lg_phys0x34f7770_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f7810">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f7810_pos" unit="mm" x="-1718" y="-1016.5" z="-586.65"/>
        <rotation name="lg_phys0x34f7810_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f7880">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f7880_pos" unit="mm" x="1718" y="-813.5" z="-586.65"/>
        <rotation name="lg_phys0x34f7880_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f7910">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f7910_pos" unit="mm" x="-1718" y="-813.5" z="-586.65"/>
        <rotation name="lg_phys0x34f7910_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f7980">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f7980_pos" unit="mm" x="1718" y="-610.5" z="-586.65"/>
        <rotation name="lg_phys0x34f7980_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f79f0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f79f0_pos" unit="mm" x="-1718" y="-610.5" z="-586.65"/>
        <rotation name="lg_phys0x34f79f0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f7a60">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f7a60_pos" unit="mm" x="1718" y="-407.5" z="-586.65"/>
        <rotation name="lg_phys0x34f7a60_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f7b60">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f7b60_pos" unit="mm" x="-1718" y="-407.5" z="-586.65"/>
        <rotation name="lg_phys0x34f7b60_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f7bd0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f7bd0_pos" unit="mm" x="1718" y="-204.5" z="-586.65"/>
        <rotation name="lg_phys0x34f7bd0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f7c40">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f7c40_pos" unit="mm" x="-1718" y="-204.5" z="-586.65"/>
        <rotation name="lg_phys0x34f7c40_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f7cb0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f7cb0_pos" unit="mm" x="1718" y="-1.5" z="-586.65"/>
        <rotation name="lg_phys0x34f7cb0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f7d20">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f7d20_pos" unit="mm" x="-1718" y="-1.5" z="-586.65"/>
        <rotation name="lg_phys0x34f7d20_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f7d90">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f7d90_pos" unit="mm" x="1718" y="201.5" z="-586.65"/>
        <rotation name="lg_phys0x34f7d90_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f7e00">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f7e00_pos" unit="mm" x="-1718" y="201.5" z="-586.65"/>
        <rotation name="lg_phys0x34f7e00_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f7e70">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f7e70_pos" unit="mm" x="1718" y="404.5" z="-586.65"/>
        <rotation name="lg_phys0x34f7e70_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f7ad0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f7ad0_pos" unit="mm" x="-1718" y="404.5" z="-586.65"/>
        <rotation name="lg_phys0x34f7ad0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f7ff0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f7ff0_pos" unit="mm" x="1718" y="607.5" z="-586.65"/>
        <rotation name="lg_phys0x34f7ff0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f8060">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f8060_pos" unit="mm" x="-1718" y="607.5" z="-586.65"/>
        <rotation name="lg_phys0x34f8060_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f80d0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f80d0_pos" unit="mm" x="1718" y="810.5" z="-586.65"/>
        <rotation name="lg_phys0x34f80d0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f8140">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f8140_pos" unit="mm" x="-1718" y="810.5" z="-586.65"/>
        <rotation name="lg_phys0x34f8140_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f81b0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f81b0_pos" unit="mm" x="1718" y="1013.5" z="-586.65"/>
        <rotation name="lg_phys0x34f81b0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f8220">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f8220_pos" unit="mm" x="-1718" y="1013.5" z="-586.65"/>
        <rotation name="lg_phys0x34f8220_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f8290">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f8290_pos" unit="mm" x="1718" y="1216.5" z="-586.65"/>
        <rotation name="lg_phys0x34f8290_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f8300">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f8300_pos" unit="mm" x="-1718" y="1216.5" z="-586.65"/>
        <rotation name="lg_phys0x34f8300_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f8370">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f8370_pos" unit="mm" x="-1422.5" y="1548" z="-465.55"/>
        <rotation name="lg_phys0x34f8370_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34f83e0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f83e0_pos" unit="mm" x="-1422.5" y="-1548" z="-465.55"/>
        <rotation name="lg_phys0x34f83e0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f8450">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f8450_pos" unit="mm" x="-1219.5" y="1548" z="-465.55"/>
        <rotation name="lg_phys0x34f8450_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34f84c0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f84c0_pos" unit="mm" x="-1219.5" y="-1548" z="-465.55"/>
        <rotation name="lg_phys0x34f84c0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f8530">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f8530_pos" unit="mm" x="-1016.5" y="1548" z="-465.55"/>
        <rotation name="lg_phys0x34f8530_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34f85a0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f85a0_pos" unit="mm" x="-1016.5" y="-1548" z="-465.55"/>
        <rotation name="lg_phys0x34f85a0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f8610">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f8610_pos" unit="mm" x="-813.5" y="1548" z="-465.55"/>
        <rotation name="lg_phys0x34f8610_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34f7ee0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f7ee0_pos" unit="mm" x="-813.5" y="-1548" z="-465.55"/>
        <rotation name="lg_phys0x34f7ee0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f7f50">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f7f50_pos" unit="mm" x="-610.5" y="1548" z="-465.55"/>
        <rotation name="lg_phys0x34f7f50_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34f8860">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f8860_pos" unit="mm" x="-610.5" y="-1548" z="-465.55"/>
        <rotation name="lg_phys0x34f8860_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f88d0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f88d0_pos" unit="mm" x="-407.5" y="1548" z="-465.55"/>
        <rotation name="lg_phys0x34f88d0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34f8940">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f8940_pos" unit="mm" x="-407.5" y="-1548" z="-465.55"/>
        <rotation name="lg_phys0x34f8940_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f89b0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f89b0_pos" unit="mm" x="-204.5" y="1548" z="-465.55"/>
        <rotation name="lg_phys0x34f89b0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34f8a20">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f8a20_pos" unit="mm" x="-204.5" y="-1548" z="-465.55"/>
        <rotation name="lg_phys0x34f8a20_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f8a90">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f8a90_pos" unit="mm" x="-1.5" y="1548" z="-465.55"/>
        <rotation name="lg_phys0x34f8a90_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34e5a90">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e5a90_pos" unit="mm" x="-1.5" y="-1548" z="-465.55"/>
        <rotation name="lg_phys0x34e5a90_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e5b00">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e5b00_pos" unit="mm" x="201.5" y="1548" z="-465.55"/>
        <rotation name="lg_phys0x34e5b00_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34e5b70">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e5b70_pos" unit="mm" x="201.5" y="-1548" z="-465.55"/>
        <rotation name="lg_phys0x34e5b70_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e5be0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e5be0_pos" unit="mm" x="404.5" y="1548" z="-465.55"/>
        <rotation name="lg_phys0x34e5be0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34e5c50">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e5c50_pos" unit="mm" x="404.5" y="-1548" z="-465.55"/>
        <rotation name="lg_phys0x34e5c50_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e5cc0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e5cc0_pos" unit="mm" x="607.5" y="1548" z="-465.55"/>
        <rotation name="lg_phys0x34e5cc0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34e5d30">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e5d30_pos" unit="mm" x="607.5" y="-1548" z="-465.55"/>
        <rotation name="lg_phys0x34e5d30_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e5da0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e5da0_pos" unit="mm" x="810.5" y="1548" z="-465.55"/>
        <rotation name="lg_phys0x34e5da0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34e5e10">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e5e10_pos" unit="mm" x="810.5" y="-1548" z="-465.55"/>
        <rotation name="lg_phys0x34e5e10_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e5e80">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e5e80_pos" unit="mm" x="1013.5" y="1548" z="-465.55"/>
        <rotation name="lg_phys0x34e5e80_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34e5ef0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e5ef0_pos" unit="mm" x="1013.5" y="-1548" z="-465.55"/>
        <rotation name="lg_phys0x34e5ef0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e5f60">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e5f60_pos" unit="mm" x="1216.5" y="1548" z="-465.55"/>
        <rotation name="lg_phys0x34e5f60_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34e5fd0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e5fd0_pos" unit="mm" x="1216.5" y="-1548" z="-465.55"/>
        <rotation name="lg_phys0x34e5fd0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e6040">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e6040_pos" unit="mm" x="1419.5" y="1548" z="-465.55"/>
        <rotation name="lg_phys0x34e6040_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34e60b0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e60b0_pos" unit="mm" x="1419.5" y="-1548" z="-465.55"/>
        <rotation name="lg_phys0x34e60b0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e6120">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e6120_pos" unit="mm" x="1718" y="-1219.5" z="-344.45"/>
        <rotation name="lg_phys0x34e6120_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e6190">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e6190_pos" unit="mm" x="-1718" y="-1219.5" z="-344.45"/>
        <rotation name="lg_phys0x34e6190_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e6200">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e6200_pos" unit="mm" x="1718" y="-1016.5" z="-344.45"/>
        <rotation name="lg_phys0x34e6200_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e6270">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e6270_pos" unit="mm" x="-1718" y="-1016.5" z="-344.45"/>
        <rotation name="lg_phys0x34e6270_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e62e0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e62e0_pos" unit="mm" x="1718" y="-813.5" z="-344.45"/>
        <rotation name="lg_phys0x34e62e0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e6350">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e6350_pos" unit="mm" x="-1718" y="-813.5" z="-344.45"/>
        <rotation name="lg_phys0x34e6350_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e63c0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e63c0_pos" unit="mm" x="1718" y="-610.5" z="-344.45"/>
        <rotation name="lg_phys0x34e63c0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e6430">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e6430_pos" unit="mm" x="-1718" y="-610.5" z="-344.45"/>
        <rotation name="lg_phys0x34e6430_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e64a0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e64a0_pos" unit="mm" x="1718" y="-407.5" z="-344.45"/>
        <rotation name="lg_phys0x34e64a0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f8680">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f8680_pos" unit="mm" x="-1718" y="-407.5" z="-344.45"/>
        <rotation name="lg_phys0x34f8680_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f86f0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f86f0_pos" unit="mm" x="1718" y="-204.5" z="-344.45"/>
        <rotation name="lg_phys0x34f86f0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f8760">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f8760_pos" unit="mm" x="-1718" y="-204.5" z="-344.45"/>
        <rotation name="lg_phys0x34f8760_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34f87d0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34f87d0_pos" unit="mm" x="1718" y="-1.5" z="-344.45"/>
        <rotation name="lg_phys0x34f87d0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e68f0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e68f0_pos" unit="mm" x="-1718" y="-1.5" z="-344.45"/>
        <rotation name="lg_phys0x34e68f0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e6960">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e6960_pos" unit="mm" x="1718" y="201.5" z="-344.45"/>
        <rotation name="lg_phys0x34e6960_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e69d0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e69d0_pos" unit="mm" x="-1718" y="201.5" z="-344.45"/>
        <rotation name="lg_phys0x34e69d0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e6a40">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e6a40_pos" unit="mm" x="1718" y="404.5" z="-344.45"/>
        <rotation name="lg_phys0x34e6a40_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e6ab0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e6ab0_pos" unit="mm" x="-1718" y="404.5" z="-344.45"/>
        <rotation name="lg_phys0x34e6ab0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e6b20">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e6b20_pos" unit="mm" x="1718" y="607.5" z="-344.45"/>
        <rotation name="lg_phys0x34e6b20_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e6b90">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e6b90_pos" unit="mm" x="-1718" y="607.5" z="-344.45"/>
        <rotation name="lg_phys0x34e6b90_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e6c00">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e6c00_pos" unit="mm" x="1718" y="810.5" z="-344.45"/>
        <rotation name="lg_phys0x34e6c00_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e6c70">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e6c70_pos" unit="mm" x="-1718" y="810.5" z="-344.45"/>
        <rotation name="lg_phys0x34e6c70_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e6ce0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e6ce0_pos" unit="mm" x="1718" y="1013.5" z="-344.45"/>
        <rotation name="lg_phys0x34e6ce0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e6d50">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e6d50_pos" unit="mm" x="-1718" y="1013.5" z="-344.45"/>
        <rotation name="lg_phys0x34e6d50_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e6dc0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e6dc0_pos" unit="mm" x="1718" y="1216.5" z="-344.45"/>
        <rotation name="lg_phys0x34e6dc0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e6e30">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e6e30_pos" unit="mm" x="-1718" y="1216.5" z="-344.45"/>
        <rotation name="lg_phys0x34e6e30_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e6ea0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e6ea0_pos" unit="mm" x="-1422.5" y="1548" z="-223.35"/>
        <rotation name="lg_phys0x34e6ea0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34e6f10">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e6f10_pos" unit="mm" x="-1422.5" y="-1548" z="-223.35"/>
        <rotation name="lg_phys0x34e6f10_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e6f80">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e6f80_pos" unit="mm" x="-1219.5" y="1548" z="-223.35"/>
        <rotation name="lg_phys0x34e6f80_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34e6ff0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e6ff0_pos" unit="mm" x="-1219.5" y="-1548" z="-223.35"/>
        <rotation name="lg_phys0x34e6ff0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e7060">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e7060_pos" unit="mm" x="-1016.5" y="1548" z="-223.35"/>
        <rotation name="lg_phys0x34e7060_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34e70d0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e70d0_pos" unit="mm" x="-1016.5" y="-1548" z="-223.35"/>
        <rotation name="lg_phys0x34e70d0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e7140">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e7140_pos" unit="mm" x="-813.5" y="1548" z="-223.35"/>
        <rotation name="lg_phys0x34e7140_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34e71b0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e71b0_pos" unit="mm" x="-813.5" y="-1548" z="-223.35"/>
        <rotation name="lg_phys0x34e71b0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e7220">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e7220_pos" unit="mm" x="-610.5" y="1548" z="-223.35"/>
        <rotation name="lg_phys0x34e7220_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34e7290">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e7290_pos" unit="mm" x="-610.5" y="-1548" z="-223.35"/>
        <rotation name="lg_phys0x34e7290_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e7300">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e7300_pos" unit="mm" x="-407.5" y="1548" z="-223.35"/>
        <rotation name="lg_phys0x34e7300_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fbce0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fbce0_pos" unit="mm" x="-407.5" y="-1548" z="-223.35"/>
        <rotation name="lg_phys0x34fbce0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fbd20">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fbd20_pos" unit="mm" x="-204.5" y="1548" z="-223.35"/>
        <rotation name="lg_phys0x34fbd20_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fbd90">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fbd90_pos" unit="mm" x="-204.5" y="-1548" z="-223.35"/>
        <rotation name="lg_phys0x34fbd90_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fbe00">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fbe00_pos" unit="mm" x="-1.5" y="1548" z="-223.35"/>
        <rotation name="lg_phys0x34fbe00_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fbe70">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fbe70_pos" unit="mm" x="-1.5" y="-1548" z="-223.35"/>
        <rotation name="lg_phys0x34fbe70_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fbee0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fbee0_pos" unit="mm" x="201.5" y="1548" z="-223.35"/>
        <rotation name="lg_phys0x34fbee0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fbf50">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fbf50_pos" unit="mm" x="201.5" y="-1548" z="-223.35"/>
        <rotation name="lg_phys0x34fbf50_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fbfc0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fbfc0_pos" unit="mm" x="404.5" y="1548" z="-223.35"/>
        <rotation name="lg_phys0x34fbfc0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fc030">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fc030_pos" unit="mm" x="404.5" y="-1548" z="-223.35"/>
        <rotation name="lg_phys0x34fc030_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fc0a0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fc0a0_pos" unit="mm" x="607.5" y="1548" z="-223.35"/>
        <rotation name="lg_phys0x34fc0a0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fc110">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fc110_pos" unit="mm" x="607.5" y="-1548" z="-223.35"/>
        <rotation name="lg_phys0x34fc110_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fc180">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fc180_pos" unit="mm" x="810.5" y="1548" z="-223.35"/>
        <rotation name="lg_phys0x34fc180_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fc1f0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fc1f0_pos" unit="mm" x="810.5" y="-1548" z="-223.35"/>
        <rotation name="lg_phys0x34fc1f0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fc260">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fc260_pos" unit="mm" x="1013.5" y="1548" z="-223.35"/>
        <rotation name="lg_phys0x34fc260_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fc2d0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fc2d0_pos" unit="mm" x="1013.5" y="-1548" z="-223.35"/>
        <rotation name="lg_phys0x34fc2d0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fc340">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fc340_pos" unit="mm" x="1216.5" y="1548" z="-223.35"/>
        <rotation name="lg_phys0x34fc340_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fc3b0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fc3b0_pos" unit="mm" x="1216.5" y="-1548" z="-223.35"/>
        <rotation name="lg_phys0x34fc3b0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fc420">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fc420_pos" unit="mm" x="1419.5" y="1548" z="-223.35"/>
        <rotation name="lg_phys0x34fc420_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fc490">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fc490_pos" unit="mm" x="1419.5" y="-1548" z="-223.35"/>
        <rotation name="lg_phys0x34fc490_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fc500">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fc500_pos" unit="mm" x="1718" y="-1219.5" z="-102.25"/>
        <rotation name="lg_phys0x34fc500_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fc570">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fc570_pos" unit="mm" x="-1718" y="-1219.5" z="-102.25"/>
        <rotation name="lg_phys0x34fc570_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fc5e0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fc5e0_pos" unit="mm" x="1718" y="-1016.5" z="-102.25"/>
        <rotation name="lg_phys0x34fc5e0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fc650">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fc650_pos" unit="mm" x="-1718" y="-1016.5" z="-102.25"/>
        <rotation name="lg_phys0x34fc650_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fc6c0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fc6c0_pos" unit="mm" x="1718" y="-813.5" z="-102.25"/>
        <rotation name="lg_phys0x34fc6c0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fc730">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fc730_pos" unit="mm" x="-1718" y="-813.5" z="-102.25"/>
        <rotation name="lg_phys0x34fc730_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fc7a0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fc7a0_pos" unit="mm" x="1718" y="-610.5" z="-102.25"/>
        <rotation name="lg_phys0x34fc7a0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fc810">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fc810_pos" unit="mm" x="-1718" y="-610.5" z="-102.25"/>
        <rotation name="lg_phys0x34fc810_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fc880">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fc880_pos" unit="mm" x="1718" y="-407.5" z="-102.25"/>
        <rotation name="lg_phys0x34fc880_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fc8f0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fc8f0_pos" unit="mm" x="-1718" y="-407.5" z="-102.25"/>
        <rotation name="lg_phys0x34fc8f0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fc960">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fc960_pos" unit="mm" x="1718" y="-204.5" z="-102.25"/>
        <rotation name="lg_phys0x34fc960_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fc9d0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fc9d0_pos" unit="mm" x="-1718" y="-204.5" z="-102.25"/>
        <rotation name="lg_phys0x34fc9d0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fca40">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fca40_pos" unit="mm" x="1718" y="-1.5" z="-102.25"/>
        <rotation name="lg_phys0x34fca40_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fcab0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fcab0_pos" unit="mm" x="-1718" y="-1.5" z="-102.25"/>
        <rotation name="lg_phys0x34fcab0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fcb20">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fcb20_pos" unit="mm" x="1718" y="201.5" z="-102.25"/>
        <rotation name="lg_phys0x34fcb20_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fcb90">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fcb90_pos" unit="mm" x="-1718" y="201.5" z="-102.25"/>
        <rotation name="lg_phys0x34fcb90_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fcc00">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fcc00_pos" unit="mm" x="1718" y="404.5" z="-102.25"/>
        <rotation name="lg_phys0x34fcc00_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e6510">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e6510_pos" unit="mm" x="-1718" y="404.5" z="-102.25"/>
        <rotation name="lg_phys0x34e6510_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e6580">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e6580_pos" unit="mm" x="1718" y="607.5" z="-102.25"/>
        <rotation name="lg_phys0x34e6580_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e65f0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e65f0_pos" unit="mm" x="-1718" y="607.5" z="-102.25"/>
        <rotation name="lg_phys0x34e65f0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e6660">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e6660_pos" unit="mm" x="1718" y="810.5" z="-102.25"/>
        <rotation name="lg_phys0x34e6660_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e66d0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e66d0_pos" unit="mm" x="-1718" y="810.5" z="-102.25"/>
        <rotation name="lg_phys0x34e66d0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e6740">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e6740_pos" unit="mm" x="1718" y="1013.5" z="-102.25"/>
        <rotation name="lg_phys0x34e6740_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e67b0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e67b0_pos" unit="mm" x="-1718" y="1013.5" z="-102.25"/>
        <rotation name="lg_phys0x34e67b0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e6820">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e6820_pos" unit="mm" x="1718" y="1216.5" z="-102.25"/>
        <rotation name="lg_phys0x34e6820_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34e6890">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34e6890_pos" unit="mm" x="-1718" y="1216.5" z="-102.25"/>
        <rotation name="lg_phys0x34e6890_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fd480">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fd480_pos" unit="mm" x="-1422.5" y="1548" z="18.85"/>
        <rotation name="lg_phys0x34fd480_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fd4f0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fd4f0_pos" unit="mm" x="-1422.5" y="-1548" z="18.85"/>
        <rotation name="lg_phys0x34fd4f0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fd560">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fd560_pos" unit="mm" x="-1219.5" y="1548" z="18.85"/>
        <rotation name="lg_phys0x34fd560_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fd5d0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fd5d0_pos" unit="mm" x="-1219.5" y="-1548" z="18.85"/>
        <rotation name="lg_phys0x34fd5d0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fd640">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fd640_pos" unit="mm" x="-1016.5" y="1548" z="18.85"/>
        <rotation name="lg_phys0x34fd640_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fd6b0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fd6b0_pos" unit="mm" x="-1016.5" y="-1548" z="18.85"/>
        <rotation name="lg_phys0x34fd6b0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fd720">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fd720_pos" unit="mm" x="-813.5" y="1548" z="18.85"/>
        <rotation name="lg_phys0x34fd720_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fd790">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fd790_pos" unit="mm" x="-813.5" y="-1548" z="18.85"/>
        <rotation name="lg_phys0x34fd790_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fd800">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fd800_pos" unit="mm" x="-610.5" y="1548" z="18.85"/>
        <rotation name="lg_phys0x34fd800_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fd870">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fd870_pos" unit="mm" x="-610.5" y="-1548" z="18.85"/>
        <rotation name="lg_phys0x34fd870_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fd8e0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fd8e0_pos" unit="mm" x="-407.5" y="1548" z="18.85"/>
        <rotation name="lg_phys0x34fd8e0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fd950">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fd950_pos" unit="mm" x="-407.5" y="-1548" z="18.85"/>
        <rotation name="lg_phys0x34fd950_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fd9c0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fd9c0_pos" unit="mm" x="-204.5" y="1548" z="18.85"/>
        <rotation name="lg_phys0x34fd9c0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fda30">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fda30_pos" unit="mm" x="-204.5" y="-1548" z="18.85"/>
        <rotation name="lg_phys0x34fda30_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fdaa0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fdaa0_pos" unit="mm" x="-1.5" y="1548" z="18.85"/>
        <rotation name="lg_phys0x34fdaa0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fdb10">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fdb10_pos" unit="mm" x="-1.5" y="-1548" z="18.85"/>
        <rotation name="lg_phys0x34fdb10_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fdb80">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fdb80_pos" unit="mm" x="201.5" y="1548" z="18.85"/>
        <rotation name="lg_phys0x34fdb80_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fdbf0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fdbf0_pos" unit="mm" x="201.5" y="-1548" z="18.85"/>
        <rotation name="lg_phys0x34fdbf0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fdc60">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fdc60_pos" unit="mm" x="404.5" y="1548" z="18.85"/>
        <rotation name="lg_phys0x34fdc60_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fdcd0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fdcd0_pos" unit="mm" x="404.5" y="-1548" z="18.85"/>
        <rotation name="lg_phys0x34fdcd0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fdd40">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fdd40_pos" unit="mm" x="607.5" y="1548" z="18.85"/>
        <rotation name="lg_phys0x34fdd40_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fddb0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fddb0_pos" unit="mm" x="607.5" y="-1548" z="18.85"/>
        <rotation name="lg_phys0x34fddb0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fde20">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fde20_pos" unit="mm" x="810.5" y="1548" z="18.85"/>
        <rotation name="lg_phys0x34fde20_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fde90">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fde90_pos" unit="mm" x="810.5" y="-1548" z="18.85"/>
        <rotation name="lg_phys0x34fde90_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fdf00">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fdf00_pos" unit="mm" x="1013.5" y="1548" z="18.85"/>
        <rotation name="lg_phys0x34fdf00_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fdf70">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fdf70_pos" unit="mm" x="1013.5" y="-1548" z="18.85"/>
        <rotation name="lg_phys0x34fdf70_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fdfe0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fdfe0_pos" unit="mm" x="1216.5" y="1548" z="18.85"/>
        <rotation name="lg_phys0x34fdfe0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fe050">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fe050_pos" unit="mm" x="1216.5" y="-1548" z="18.85"/>
        <rotation name="lg_phys0x34fe050_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fe0c0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fe0c0_pos" unit="mm" x="1419.5" y="1548" z="18.85"/>
        <rotation name="lg_phys0x34fe0c0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fe130">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fe130_pos" unit="mm" x="1419.5" y="-1548" z="18.85"/>
        <rotation name="lg_phys0x34fe130_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fe1a0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fe1a0_pos" unit="mm" x="1718" y="-1219.5" z="139.95"/>
        <rotation name="lg_phys0x34fe1a0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fe210">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fe210_pos" unit="mm" x="-1718" y="-1219.5" z="139.95"/>
        <rotation name="lg_phys0x34fe210_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fe280">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fe280_pos" unit="mm" x="1718" y="-1016.5" z="139.95"/>
        <rotation name="lg_phys0x34fe280_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fe2f0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fe2f0_pos" unit="mm" x="-1718" y="-1016.5" z="139.95"/>
        <rotation name="lg_phys0x34fe2f0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fe360">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fe360_pos" unit="mm" x="1718" y="-813.5" z="139.95"/>
        <rotation name="lg_phys0x34fe360_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fe3d0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fe3d0_pos" unit="mm" x="-1718" y="-813.5" z="139.95"/>
        <rotation name="lg_phys0x34fe3d0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fe440">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fe440_pos" unit="mm" x="1718" y="-610.5" z="139.95"/>
        <rotation name="lg_phys0x34fe440_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fe4b0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fe4b0_pos" unit="mm" x="-1718" y="-610.5" z="139.95"/>
        <rotation name="lg_phys0x34fe4b0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fe520">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fe520_pos" unit="mm" x="1718" y="-407.5" z="139.95"/>
        <rotation name="lg_phys0x34fe520_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fe590">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fe590_pos" unit="mm" x="-1718" y="-407.5" z="139.95"/>
        <rotation name="lg_phys0x34fe590_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fe600">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fe600_pos" unit="mm" x="1718" y="-204.5" z="139.95"/>
        <rotation name="lg_phys0x34fe600_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fe670">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fe670_pos" unit="mm" x="-1718" y="-204.5" z="139.95"/>
        <rotation name="lg_phys0x34fe670_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fe6e0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fe6e0_pos" unit="mm" x="1718" y="-1.5" z="139.95"/>
        <rotation name="lg_phys0x34fe6e0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fe750">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fe750_pos" unit="mm" x="-1718" y="-1.5" z="139.95"/>
        <rotation name="lg_phys0x34fe750_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fe7c0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fe7c0_pos" unit="mm" x="1718" y="201.5" z="139.95"/>
        <rotation name="lg_phys0x34fe7c0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fe830">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fe830_pos" unit="mm" x="-1718" y="201.5" z="139.95"/>
        <rotation name="lg_phys0x34fe830_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fe8a0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fe8a0_pos" unit="mm" x="1718" y="404.5" z="139.95"/>
        <rotation name="lg_phys0x34fe8a0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fe910">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fe910_pos" unit="mm" x="-1718" y="404.5" z="139.95"/>
        <rotation name="lg_phys0x34fe910_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fe980">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fe980_pos" unit="mm" x="1718" y="607.5" z="139.95"/>
        <rotation name="lg_phys0x34fe980_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fe9f0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fe9f0_pos" unit="mm" x="-1718" y="607.5" z="139.95"/>
        <rotation name="lg_phys0x34fe9f0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fea60">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fea60_pos" unit="mm" x="1718" y="810.5" z="139.95"/>
        <rotation name="lg_phys0x34fea60_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fead0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fead0_pos" unit="mm" x="-1718" y="810.5" z="139.95"/>
        <rotation name="lg_phys0x34fead0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34feb40">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34feb40_pos" unit="mm" x="1718" y="1013.5" z="139.95"/>
        <rotation name="lg_phys0x34feb40_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34febb0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34febb0_pos" unit="mm" x="-1718" y="1013.5" z="139.95"/>
        <rotation name="lg_phys0x34febb0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fec20">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fec20_pos" unit="mm" x="1718" y="1216.5" z="139.95"/>
        <rotation name="lg_phys0x34fec20_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fec90">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fec90_pos" unit="mm" x="-1718" y="1216.5" z="139.95"/>
        <rotation name="lg_phys0x34fec90_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fed00">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fed00_pos" unit="mm" x="-1422.5" y="1548" z="261.05"/>
        <rotation name="lg_phys0x34fed00_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fed70">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fed70_pos" unit="mm" x="-1422.5" y="-1548" z="261.05"/>
        <rotation name="lg_phys0x34fed70_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fede0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fede0_pos" unit="mm" x="-1219.5" y="1548" z="261.05"/>
        <rotation name="lg_phys0x34fede0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fee50">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fee50_pos" unit="mm" x="-1219.5" y="-1548" z="261.05"/>
        <rotation name="lg_phys0x34fee50_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34feec0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34feec0_pos" unit="mm" x="-1016.5" y="1548" z="261.05"/>
        <rotation name="lg_phys0x34feec0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fef30">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fef30_pos" unit="mm" x="-1016.5" y="-1548" z="261.05"/>
        <rotation name="lg_phys0x34fef30_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fefa0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fefa0_pos" unit="mm" x="-813.5" y="1548" z="261.05"/>
        <rotation name="lg_phys0x34fefa0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34ff010">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ff010_pos" unit="mm" x="-813.5" y="-1548" z="261.05"/>
        <rotation name="lg_phys0x34ff010_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34ff080">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ff080_pos" unit="mm" x="-610.5" y="1548" z="261.05"/>
        <rotation name="lg_phys0x34ff080_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34ff0f0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ff0f0_pos" unit="mm" x="-610.5" y="-1548" z="261.05"/>
        <rotation name="lg_phys0x34ff0f0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34ff160">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ff160_pos" unit="mm" x="-407.5" y="1548" z="261.05"/>
        <rotation name="lg_phys0x34ff160_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34ff1d0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ff1d0_pos" unit="mm" x="-407.5" y="-1548" z="261.05"/>
        <rotation name="lg_phys0x34ff1d0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34ff240">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ff240_pos" unit="mm" x="-204.5" y="1548" z="261.05"/>
        <rotation name="lg_phys0x34ff240_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34ff2b0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ff2b0_pos" unit="mm" x="-204.5" y="-1548" z="261.05"/>
        <rotation name="lg_phys0x34ff2b0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34ff320">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ff320_pos" unit="mm" x="-1.5" y="1548" z="261.05"/>
        <rotation name="lg_phys0x34ff320_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34ff390">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ff390_pos" unit="mm" x="-1.5" y="-1548" z="261.05"/>
        <rotation name="lg_phys0x34ff390_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34ff400">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ff400_pos" unit="mm" x="201.5" y="1548" z="261.05"/>
        <rotation name="lg_phys0x34ff400_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34ff470">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ff470_pos" unit="mm" x="201.5" y="-1548" z="261.05"/>
        <rotation name="lg_phys0x34ff470_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34ff4e0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ff4e0_pos" unit="mm" x="404.5" y="1548" z="261.05"/>
        <rotation name="lg_phys0x34ff4e0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34ff550">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ff550_pos" unit="mm" x="404.5" y="-1548" z="261.05"/>
        <rotation name="lg_phys0x34ff550_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34ff5c0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ff5c0_pos" unit="mm" x="607.5" y="1548" z="261.05"/>
        <rotation name="lg_phys0x34ff5c0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34ff630">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ff630_pos" unit="mm" x="607.5" y="-1548" z="261.05"/>
        <rotation name="lg_phys0x34ff630_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34ff6a0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ff6a0_pos" unit="mm" x="810.5" y="1548" z="261.05"/>
        <rotation name="lg_phys0x34ff6a0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34ff710">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ff710_pos" unit="mm" x="810.5" y="-1548" z="261.05"/>
        <rotation name="lg_phys0x34ff710_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34ff780">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ff780_pos" unit="mm" x="1013.5" y="1548" z="261.05"/>
        <rotation name="lg_phys0x34ff780_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34ff7f0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ff7f0_pos" unit="mm" x="1013.5" y="-1548" z="261.05"/>
        <rotation name="lg_phys0x34ff7f0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34ff860">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ff860_pos" unit="mm" x="1216.5" y="1548" z="261.05"/>
        <rotation name="lg_phys0x34ff860_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34ff8d0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ff8d0_pos" unit="mm" x="1216.5" y="-1548" z="261.05"/>
        <rotation name="lg_phys0x34ff8d0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34ff940">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ff940_pos" unit="mm" x="1419.5" y="1548" z="261.05"/>
        <rotation name="lg_phys0x34ff940_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34ff9b0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ff9b0_pos" unit="mm" x="1419.5" y="-1548" z="261.05"/>
        <rotation name="lg_phys0x34ff9b0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34ffa20">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ffa20_pos" unit="mm" x="1718" y="-1219.5" z="382.15"/>
        <rotation name="lg_phys0x34ffa20_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34ffa90">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ffa90_pos" unit="mm" x="-1718" y="-1219.5" z="382.15"/>
        <rotation name="lg_phys0x34ffa90_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34ffb00">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ffb00_pos" unit="mm" x="1718" y="-1016.5" z="382.15"/>
        <rotation name="lg_phys0x34ffb00_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34ffb70">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ffb70_pos" unit="mm" x="-1718" y="-1016.5" z="382.15"/>
        <rotation name="lg_phys0x34ffb70_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34ffbe0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ffbe0_pos" unit="mm" x="1718" y="-813.5" z="382.15"/>
        <rotation name="lg_phys0x34ffbe0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34ffc50">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ffc50_pos" unit="mm" x="-1718" y="-813.5" z="382.15"/>
        <rotation name="lg_phys0x34ffc50_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34ffcc0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ffcc0_pos" unit="mm" x="1718" y="-610.5" z="382.15"/>
        <rotation name="lg_phys0x34ffcc0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34ffd30">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ffd30_pos" unit="mm" x="-1718" y="-610.5" z="382.15"/>
        <rotation name="lg_phys0x34ffd30_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34ffda0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ffda0_pos" unit="mm" x="1718" y="-407.5" z="382.15"/>
        <rotation name="lg_phys0x34ffda0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34ffe10">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ffe10_pos" unit="mm" x="-1718" y="-407.5" z="382.15"/>
        <rotation name="lg_phys0x34ffe10_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34ffe80">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ffe80_pos" unit="mm" x="1718" y="-204.5" z="382.15"/>
        <rotation name="lg_phys0x34ffe80_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34ffef0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ffef0_pos" unit="mm" x="-1718" y="-204.5" z="382.15"/>
        <rotation name="lg_phys0x34ffef0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fff60">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fff60_pos" unit="mm" x="1718" y="-1.5" z="382.15"/>
        <rotation name="lg_phys0x34fff60_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fffd0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fffd0_pos" unit="mm" x="-1718" y="-1.5" z="382.15"/>
        <rotation name="lg_phys0x34fffd0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x3500040">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x3500040_pos" unit="mm" x="1718" y="201.5" z="382.15"/>
        <rotation name="lg_phys0x3500040_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x35000b0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x35000b0_pos" unit="mm" x="-1718" y="201.5" z="382.15"/>
        <rotation name="lg_phys0x35000b0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x3500120">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x3500120_pos" unit="mm" x="1718" y="404.5" z="382.15"/>
        <rotation name="lg_phys0x3500120_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x3500190">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x3500190_pos" unit="mm" x="-1718" y="404.5" z="382.15"/>
        <rotation name="lg_phys0x3500190_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x3500200">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x3500200_pos" unit="mm" x="1718" y="607.5" z="382.15"/>
        <rotation name="lg_phys0x3500200_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x3500270">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x3500270_pos" unit="mm" x="-1718" y="607.5" z="382.15"/>
        <rotation name="lg_phys0x3500270_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x35002e0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x35002e0_pos" unit="mm" x="1718" y="810.5" z="382.15"/>
        <rotation name="lg_phys0x35002e0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x3500350">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x3500350_pos" unit="mm" x="-1718" y="810.5" z="382.15"/>
        <rotation name="lg_phys0x3500350_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x35003c0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x35003c0_pos" unit="mm" x="1718" y="1013.5" z="382.15"/>
        <rotation name="lg_phys0x35003c0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x3500430">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x3500430_pos" unit="mm" x="-1718" y="1013.5" z="382.15"/>
        <rotation name="lg_phys0x3500430_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x35004a0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x35004a0_pos" unit="mm" x="1718" y="1216.5" z="382.15"/>
        <rotation name="lg_phys0x35004a0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x3500510">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x3500510_pos" unit="mm" x="-1718" y="1216.5" z="382.15"/>
        <rotation name="lg_phys0x3500510_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x3500580">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x3500580_pos" unit="mm" x="-1422.5" y="1548" z="503.25"/>
        <rotation name="lg_phys0x3500580_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x35005f0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x35005f0_pos" unit="mm" x="-1422.5" y="-1548" z="503.25"/>
        <rotation name="lg_phys0x35005f0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x3500660">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x3500660_pos" unit="mm" x="-1219.5" y="1548" z="503.25"/>
        <rotation name="lg_phys0x3500660_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x35006d0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x35006d0_pos" unit="mm" x="-1219.5" y="-1548" z="503.25"/>
        <rotation name="lg_phys0x35006d0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x3500740">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x3500740_pos" unit="mm" x="-1016.5" y="1548" z="503.25"/>
        <rotation name="lg_phys0x3500740_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x35007b0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x35007b0_pos" unit="mm" x="-1016.5" y="-1548" z="503.25"/>
        <rotation name="lg_phys0x35007b0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x3500820">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x3500820_pos" unit="mm" x="-813.5" y="1548" z="503.25"/>
        <rotation name="lg_phys0x3500820_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fcc70">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fcc70_pos" unit="mm" x="-813.5" y="-1548" z="503.25"/>
        <rotation name="lg_phys0x34fcc70_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fcce0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fcce0_pos" unit="mm" x="-610.5" y="1548" z="503.25"/>
        <rotation name="lg_phys0x34fcce0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fcd50">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fcd50_pos" unit="mm" x="-610.5" y="-1548" z="503.25"/>
        <rotation name="lg_phys0x34fcd50_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fcdc0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fcdc0_pos" unit="mm" x="-407.5" y="1548" z="503.25"/>
        <rotation name="lg_phys0x34fcdc0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fce30">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fce30_pos" unit="mm" x="-407.5" y="-1548" z="503.25"/>
        <rotation name="lg_phys0x34fce30_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fcea0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fcea0_pos" unit="mm" x="-204.5" y="1548" z="503.25"/>
        <rotation name="lg_phys0x34fcea0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fcf10">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fcf10_pos" unit="mm" x="-204.5" y="-1548" z="503.25"/>
        <rotation name="lg_phys0x34fcf10_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fcf80">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fcf80_pos" unit="mm" x="-1.5" y="1548" z="503.25"/>
        <rotation name="lg_phys0x34fcf80_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fcff0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fcff0_pos" unit="mm" x="-1.5" y="-1548" z="503.25"/>
        <rotation name="lg_phys0x34fcff0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fd060">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fd060_pos" unit="mm" x="201.5" y="1548" z="503.25"/>
        <rotation name="lg_phys0x34fd060_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fd0d0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fd0d0_pos" unit="mm" x="201.5" y="-1548" z="503.25"/>
        <rotation name="lg_phys0x34fd0d0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fd140">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fd140_pos" unit="mm" x="404.5" y="1548" z="503.25"/>
        <rotation name="lg_phys0x34fd140_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fd1b0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fd1b0_pos" unit="mm" x="404.5" y="-1548" z="503.25"/>
        <rotation name="lg_phys0x34fd1b0_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fd220">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fd220_pos" unit="mm" x="607.5" y="1548" z="503.25"/>
        <rotation name="lg_phys0x34fd220_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fd290">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fd290_pos" unit="mm" x="607.5" y="-1548" z="503.25"/>
        <rotation name="lg_phys0x34fd290_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fd300">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fd300_pos" unit="mm" x="810.5" y="1548" z="503.25"/>
        <rotation name="lg_phys0x34fd300_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34fd370">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fd370_pos" unit="mm" x="810.5" y="-1548" z="503.25"/>
        <rotation name="lg_phys0x34fd370_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34fd3e0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34fd3e0_pos" unit="mm" x="1013.5" y="1548" z="503.25"/>
        <rotation name="lg_phys0x34fd3e0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34eab60">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34eab60_pos" unit="mm" x="1013.5" y="-1548" z="503.25"/>
        <rotation name="lg_phys0x34eab60_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34eabd0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34eabd0_pos" unit="mm" x="1216.5" y="1548" z="503.25"/>
        <rotation name="lg_phys0x34eabd0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34eac40">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34eac40_pos" unit="mm" x="1216.5" y="-1548" z="503.25"/>
        <rotation name="lg_phys0x34eac40_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34eacb0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34eacb0_pos" unit="mm" x="1419.5" y="1548" z="503.25"/>
        <rotation name="lg_phys0x34eacb0_rot" unit="deg" x="90" y="0" z="-180"/>
      </physvol>
      <physvol name="lg_phys0x34ead20">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ead20_pos" unit="mm" x="1419.5" y="-1548" z="503.25"/>
        <rotation name="lg_phys0x34ead20_rot" unit="deg" x="-90" y="0" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34ead90">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34ead90_pos" unit="mm" x="1718" y="-1219.5" z="624.35"/>
        <rotation name="lg_phys0x34ead90_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34eae00">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34eae00_pos" unit="mm" x="-1718" y="-1219.5" z="624.35"/>
        <rotation name="lg_phys0x34eae00_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34eae70">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34eae70_pos" unit="mm" x="1718" y="-1016.5" z="624.35"/>
        <rotation name="lg_phys0x34eae70_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34eaee0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34eaee0_pos" unit="mm" x="-1718" y="-1016.5" z="624.35"/>
        <rotation name="lg_phys0x34eaee0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34eaf50">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34eaf50_pos" unit="mm" x="1718" y="-813.5" z="624.35"/>
        <rotation name="lg_phys0x34eaf50_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34eafc0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34eafc0_pos" unit="mm" x="-1718" y="-813.5" z="624.35"/>
        <rotation name="lg_phys0x34eafc0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34eb030">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34eb030_pos" unit="mm" x="1718" y="-610.5" z="624.35"/>
        <rotation name="lg_phys0x34eb030_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34eb0a0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34eb0a0_pos" unit="mm" x="-1718" y="-610.5" z="624.35"/>
        <rotation name="lg_phys0x34eb0a0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34eb110">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34eb110_pos" unit="mm" x="1718" y="-407.5" z="624.35"/>
        <rotation name="lg_phys0x34eb110_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34eb180">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34eb180_pos" unit="mm" x="-1718" y="-407.5" z="624.35"/>
        <rotation name="lg_phys0x34eb180_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34eb1f0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34eb1f0_pos" unit="mm" x="1718" y="-204.5" z="624.35"/>
        <rotation name="lg_phys0x34eb1f0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34eb260">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34eb260_pos" unit="mm" x="-1718" y="-204.5" z="624.35"/>
        <rotation name="lg_phys0x34eb260_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34eb2d0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34eb2d0_pos" unit="mm" x="1718" y="-1.5" z="624.35"/>
        <rotation name="lg_phys0x34eb2d0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34eb340">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34eb340_pos" unit="mm" x="-1718" y="-1.5" z="624.35"/>
        <rotation name="lg_phys0x34eb340_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34eb3b0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34eb3b0_pos" unit="mm" x="1718" y="201.5" z="624.35"/>
        <rotation name="lg_phys0x34eb3b0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34eb420">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34eb420_pos" unit="mm" x="-1718" y="201.5" z="624.35"/>
        <rotation name="lg_phys0x34eb420_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34eb490">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34eb490_pos" unit="mm" x="1718" y="404.5" z="624.35"/>
        <rotation name="lg_phys0x34eb490_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34eb500">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34eb500_pos" unit="mm" x="-1718" y="404.5" z="624.35"/>
        <rotation name="lg_phys0x34eb500_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34eb570">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34eb570_pos" unit="mm" x="1718" y="607.5" z="624.35"/>
        <rotation name="lg_phys0x34eb570_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34eb5e0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34eb5e0_pos" unit="mm" x="-1718" y="607.5" z="624.35"/>
        <rotation name="lg_phys0x34eb5e0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34eb650">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34eb650_pos" unit="mm" x="1718" y="810.5" z="624.35"/>
        <rotation name="lg_phys0x34eb650_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34eb6c0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34eb6c0_pos" unit="mm" x="-1718" y="810.5" z="624.35"/>
        <rotation name="lg_phys0x34eb6c0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34eb730">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34eb730_pos" unit="mm" x="1718" y="1013.5" z="624.35"/>
        <rotation name="lg_phys0x34eb730_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34eb7a0">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34eb7a0_pos" unit="mm" x="-1718" y="1013.5" z="624.35"/>
        <rotation name="lg_phys0x34eb7a0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34eb810">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34eb810_pos" unit="mm" x="1718" y="1216.5" z="624.35"/>
        <rotation name="lg_phys0x34eb810_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="lg_phys0x34eb880">
        <volumeref ref="lg_log0x34f7610"/>
        <position name="lg_phys0x34eb880_pos" unit="mm" x="-1718" y="1216.5" z="624.35"/>
        <rotation name="lg_phys0x34eb880_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="steel_phys0x34eb8c0">
        <volumeref ref="steel_log0x34eb960"/>
        <position name="steel_phys0x34eb8c0_pos" unit="mm" x="0" y="0" z="-619.65"/>
      </physvol>
      <physvol name="steel_phys0x34eba10">
        <volumeref ref="steel_log0x34eb960"/>
        <position name="steel_phys0x34eba10_pos" unit="mm" x="0" y="0" z="-498.55"/>
      </physvol>
      <physvol name="steel_phys0x34eba80">
        <volumeref ref="steel_log0x34eb960"/>
        <position name="steel_phys0x34eba80_pos" unit="mm" x="0" y="0" z="-377.45"/>
      </physvol>
      <physvol name="steel_phys0x34ebaf0">
        <volumeref ref="steel_log0x34eb960"/>
        <position name="steel_phys0x34ebaf0_pos" unit="mm" x="0" y="0" z="-256.35"/>
      </physvol>
      <physvol name="steel_phys0x34ebb60">
        <volumeref ref="steel_log0x34eb960"/>
        <position name="steel_phys0x34ebb60_pos" unit="mm" x="0" y="0" z="-135.25"/>
      </physvol>
      <physvol name="steel_phys0x34ebbd0">
        <volumeref ref="steel_log0x34eb960"/>
        <position name="steel_phys0x34ebbd0_pos" unit="mm" x="0" y="0" z="-14.15"/>
      </physvol>
      <physvol name="steel_phys0x34ebc40">
        <volumeref ref="steel_log0x34eb960"/>
        <position name="steel_phys0x34ebc40_pos" unit="mm" x="0" y="0" z="106.95"/>
      </physvol>
      <physvol name="steel_phys0x34ebcb0">
        <volumeref ref="steel_log0x34eb960"/>
        <position name="steel_phys0x34ebcb0_pos" unit="mm" x="0" y="0" z="228.05"/>
      </physvol>
      <physvol name="steel_phys0x34ebd20">
        <volumeref ref="steel_log0x34eb960"/>
        <position name="steel_phys0x34ebd20_pos" unit="mm" x="0" y="0" z="349.15"/>
      </physvol>
      <physvol name="steel_phys0x34ebd90">
        <volumeref ref="steel_log0x34eb960"/>
        <position name="steel_phys0x34ebd90_pos" unit="mm" x="0" y="0" z="470.25"/>
      </physvol>
      <physvol name="steel_phys0x34ebe00">
        <volumeref ref="steel_log0x34eb960"/>
        <position name="steel_phys0x34ebe00_pos" unit="mm" x="0" y="0" z="591.35"/>
      </physvol>
      <physvol name="av_1_impr_1_aluStruct_pv_00x35512e0">
        <volumeref ref="aluStruct0x3550db0"/>
        <position name="av_1_impr_1_aluStruct_pv_00x35512e0_pos" unit="mm" x="0" y="0" z="-562.6"/>
      </physvol>
      <physvol name="av_1_impr_1_aluStruct_pv_10x3551c00">
        <volumeref ref="aluStruct0x3550db0"/>
        <position name="av_1_impr_1_aluStruct_pv_10x3551c00_pos" unit="mm" x="0" y="0" z="-441.5"/>
      </physvol>
      <physvol name="av_1_impr_1_aluStruct_pv_20x3551c80">
        <volumeref ref="aluStruct0x3550db0"/>
        <position name="av_1_impr_1_aluStruct_pv_20x3551c80_pos" unit="mm" x="0" y="0" z="-320.4"/>
      </physvol>
      <physvol name="av_1_impr_1_aluStruct_pv_30x3551d00">
        <volumeref ref="aluStruct0x3550db0"/>
        <position name="av_1_impr_1_aluStruct_pv_30x3551d00_pos" unit="mm" x="0" y="0" z="-199.3"/>
      </physvol>
      <physvol name="av_1_impr_1_aluStruct_pv_40x3551d80">
        <volumeref ref="aluStruct0x3550db0"/>
        <position name="av_1_impr_1_aluStruct_pv_40x3551d80_pos" unit="mm" x="0" y="0" z="-78.2"/>
      </physvol>
      <physvol name="av_1_impr_1_aluStruct_pv_50x3551e50">
        <volumeref ref="aluStruct0x3550db0"/>
        <position name="av_1_impr_1_aluStruct_pv_50x3551e50_pos" unit="mm" x="0" y="0" z="42.9"/>
      </physvol>
      <physvol name="av_1_impr_1_aluStruct_pv_60x3551ed0">
        <volumeref ref="aluStruct0x3550db0"/>
        <position name="av_1_impr_1_aluStruct_pv_60x3551ed0_pos" unit="mm" x="0" y="0" z="164"/>
      </physvol>
      <physvol name="av_1_impr_1_aluStruct_pv_70x3551f50">
        <volumeref ref="aluStruct0x3550db0"/>
        <position name="av_1_impr_1_aluStruct_pv_70x3551f50_pos" unit="mm" x="0" y="0" z="285.1"/>
      </physvol>
      <physvol name="av_1_impr_1_aluStruct_pv_80x3551fd0">
        <volumeref ref="aluStruct0x3550db0"/>
        <position name="av_1_impr_1_aluStruct_pv_80x3551fd0_pos" unit="mm" x="0" y="0" z="406.2"/>
      </physvol>
      <physvol name="av_1_impr_1_aluStruct_pv_90x35520e0">
        <volumeref ref="aluStruct0x3550db0"/>
        <position name="av_1_impr_1_aluStruct_pv_90x35520e0_pos" unit="mm" x="0" y="0" z="527.3"/>
      </physvol>
      <physvol name="av_1_impr_1_aluStruct_pv_100x3552160">
        <volumeref ref="aluStruct0x3550db0"/>
        <position name="av_1_impr_1_aluStruct_pv_100x3552160_pos" unit="mm" x="0" y="0" z="648.4"/>
      </physvol>
    </volume>
    <volume name="vetoPaddle_log0x3551890">
      <materialref ref="Scinti"/>
      <solidref ref="vetoPaddle_box0x34dc190"/>
    </volume>
    <volume name="vetol2Paddle_log0x3551910">
      <materialref ref="Scinti"/>
      <solidref ref="vetoPaddle_box0x34dc190"/>
    </volume>
    <volume name="vetolg_log0x3552dd0">
      <materialref ref="Glass"/>
      <solidref ref="vetoLG_box0x34dc2b0"/>
    </volume>
    <volume name="totVetolog0x3550f10">
      <materialref ref="Vacuum"/>
      <solidref ref="totVeto_box0x34dc350"/>
      <physvol name="vetoPaddle_phys0x3551990">
        <volumeref ref="vetoPaddle_log0x3551890"/>
        <position name="vetoPaddle_phys0x3551990_pos" unit="mm" x="0" y="-1849.35" z="-41.8"/>
      </physvol>
      <physvol name="vetoPaddle_phys0x3551a00">
        <volumeref ref="vetoPaddle_log0x3551890"/>
        <position name="vetoPaddle_phys0x3551a00_pos" unit="mm" x="0" y="-1542.35" z="-41.8"/>
      </physvol>
      <physvol name="vetoPaddle_phys0x3551a70">
        <volumeref ref="vetoPaddle_log0x3551890"/>
        <position name="vetoPaddle_phys0x3551a70_pos" unit="mm" x="0" y="-1235.35" z="-41.8"/>
      </physvol>
      <physvol name="vetoPaddle_phys0x3551b40">
        <volumeref ref="vetoPaddle_log0x3551890"/>
        <position name="vetoPaddle_phys0x3551b40_pos" unit="mm" x="0" y="-928.35" z="-41.8"/>
      </physvol>
      <physvol name="vetoPaddle_phys0x35521a0">
        <volumeref ref="vetoPaddle_log0x3551890"/>
        <position name="vetoPaddle_phys0x35521a0_pos" unit="mm" x="0" y="-621.35" z="-41.8"/>
      </physvol>
      <physvol name="vetoPaddle_phys0x3552230">
        <volumeref ref="vetoPaddle_log0x3551890"/>
        <position name="vetoPaddle_phys0x3552230_pos" unit="mm" x="0" y="-314.35" z="-41.8"/>
      </physvol>
      <physvol name="vetoPaddle_phys0x3552270">
        <volumeref ref="vetoPaddle_log0x3551890"/>
        <position name="vetoPaddle_phys0x3552270_pos" unit="mm" x="0" y="-7.35" z="-41.8"/>
      </physvol>
      <physvol name="vetoPaddle_phys0x35522e0">
        <volumeref ref="vetoPaddle_log0x3551890"/>
        <position name="vetoPaddle_phys0x35522e0_pos" unit="mm" x="0" y="299.65" z="-41.8"/>
      </physvol>
      <physvol name="vetoPaddle_phys0x3552350">
        <volumeref ref="vetoPaddle_log0x3551890"/>
        <position name="vetoPaddle_phys0x3552350_pos" unit="mm" x="0" y="606.65" z="-41.8"/>
      </physvol>
      <physvol name="vetoPaddle_phys0x35524e0">
        <volumeref ref="vetoPaddle_log0x3551890"/>
        <position name="vetoPaddle_phys0x35524e0_pos" unit="mm" x="0" y="913.65" z="-41.8"/>
      </physvol>
      <physvol name="vetoPaddle_phys0x3552550">
        <volumeref ref="vetoPaddle_log0x3551890"/>
        <position name="vetoPaddle_phys0x3552550_pos" unit="mm" x="0" y="1220.65" z="-41.8"/>
      </physvol>
      <physvol name="vetoPaddle_phys0x35525c0">
        <volumeref ref="vetoPaddle_log0x3551890"/>
        <position name="vetoPaddle_phys0x35525c0_pos" unit="mm" x="0" y="1527.65" z="-41.8"/>
      </physvol>
      <physvol name="vetoPaddle_phys0x3552630">
        <volumeref ref="vetoPaddle_log0x3551890"/>
        <position name="vetoPaddle_phys0x3552630_pos" unit="mm" x="0" y="1834.65" z="-41.8"/>
      </physvol>
      <physvol name="vetoPaddle_phys0x35526a0">
        <volumeref ref="vetol2Paddle_log0x3551910"/>
        <position name="vetoPaddle_phys0x35526a0_pos" unit="mm" x="0" y="-1843" z="-19.8"/>
      </physvol>
      <physvol name="vetoPaddle_phys0x3552710">
        <volumeref ref="vetol2Paddle_log0x3551910"/>
        <position name="vetoPaddle_phys0x3552710_pos" unit="mm" x="0" y="-1536" z="-19.8"/>
      </physvol>
      <physvol name="vetoPaddle_phys0x3552780">
        <volumeref ref="vetol2Paddle_log0x3551910"/>
        <position name="vetoPaddle_phys0x3552780_pos" unit="mm" x="0" y="-1229" z="-19.8"/>
      </physvol>
      <physvol name="vetoPaddle_phys0x35527f0">
        <volumeref ref="vetol2Paddle_log0x3551910"/>
        <position name="vetoPaddle_phys0x35527f0_pos" unit="mm" x="0" y="-922" z="-19.8"/>
      </physvol>
      <physvol name="vetoPaddle_phys0x35523c0">
        <volumeref ref="vetol2Paddle_log0x3551910"/>
        <position name="vetoPaddle_phys0x35523c0_pos" unit="mm" x="0" y="-615" z="-19.8"/>
      </physvol>
      <physvol name="vetoPaddle_phys0x3552430">
        <volumeref ref="vetol2Paddle_log0x3551910"/>
        <position name="vetoPaddle_phys0x3552430_pos" unit="mm" x="0" y="-308" z="-19.8"/>
      </physvol>
      <physvol name="vetoPaddle_phys0x3552a50">
        <volumeref ref="vetol2Paddle_log0x3551910"/>
        <position name="vetoPaddle_phys0x3552a50_pos" unit="mm" x="0" y="-1" z="-19.8"/>
      </physvol>
      <physvol name="vetoPaddle_phys0x3552ac0">
        <volumeref ref="vetol2Paddle_log0x3551910"/>
        <position name="vetoPaddle_phys0x3552ac0_pos" unit="mm" x="0" y="306" z="-19.8"/>
      </physvol>
      <physvol name="vetoPaddle_phys0x3552b30">
        <volumeref ref="vetol2Paddle_log0x3551910"/>
        <position name="vetoPaddle_phys0x3552b30_pos" unit="mm" x="0" y="613" z="-19.8"/>
      </physvol>
      <physvol name="vetoPaddle_phys0x3552ba0">
        <volumeref ref="vetol2Paddle_log0x3551910"/>
        <position name="vetoPaddle_phys0x3552ba0_pos" unit="mm" x="0" y="920" z="-19.8"/>
      </physvol>
      <physvol name="vetoPaddle_phys0x3552c10">
        <volumeref ref="vetol2Paddle_log0x3551910"/>
        <position name="vetoPaddle_phys0x3552c10_pos" unit="mm" x="0" y="1227" z="-19.8"/>
      </physvol>
      <physvol name="vetoPaddle_phys0x3552c80">
        <volumeref ref="vetol2Paddle_log0x3551910"/>
        <position name="vetoPaddle_phys0x3552c80_pos" unit="mm" x="0" y="1534" z="-19.8"/>
      </physvol>
      <physvol name="vetoPaddle_phys0x3552cf0">
        <volumeref ref="vetol2Paddle_log0x3551910"/>
        <position name="vetoPaddle_phys0x3552cf0_pos" unit="mm" x="0" y="1841" z="-19.8"/>
      </physvol>
      <physvol name="vetolg_phys0x3552d30">
        <volumeref ref="vetolg_log0x3552dd0"/>
        <position name="vetolg_phys0x3552d30_pos" unit="mm" x="-1850" y="-1849.35" z="-41.8"/>
        <rotation name="vetolg_phys0x3552d30_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="vetolg_phys0x3552ef0">
        <volumeref ref="vetolg_log0x3552dd0"/>
        <position name="vetolg_phys0x3552ef0_pos" unit="mm" x="-1850" y="-1542.35" z="-41.8"/>
        <rotation name="vetolg_phys0x3552ef0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="vetolg_phys0x3552f60">
        <volumeref ref="vetolg_log0x3552dd0"/>
        <position name="vetolg_phys0x3552f60_pos" unit="mm" x="-1850" y="-1235.35" z="-41.8"/>
        <rotation name="vetolg_phys0x3552f60_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="vetolg_phys0x3553000">
        <volumeref ref="vetolg_log0x3552dd0"/>
        <position name="vetolg_phys0x3553000_pos" unit="mm" x="-1850" y="-928.35" z="-41.8"/>
        <rotation name="vetolg_phys0x3553000_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="vetolg_phys0x3553070">
        <volumeref ref="vetolg_log0x3552dd0"/>
        <position name="vetolg_phys0x3553070_pos" unit="mm" x="-1850" y="-621.35" z="-41.8"/>
        <rotation name="vetolg_phys0x3553070_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="vetolg_phys0x35530b0">
        <volumeref ref="vetolg_log0x3552dd0"/>
        <position name="vetolg_phys0x35530b0_pos" unit="mm" x="-1850" y="-314.35" z="-41.8"/>
        <rotation name="vetolg_phys0x35530b0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="vetolg_phys0x3553120">
        <volumeref ref="vetolg_log0x3552dd0"/>
        <position name="vetolg_phys0x3553120_pos" unit="mm" x="-1850" y="-7.35" z="-41.8"/>
        <rotation name="vetolg_phys0x3553120_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="vetolg_phys0x3552860">
        <volumeref ref="vetolg_log0x3552dd0"/>
        <position name="vetolg_phys0x3552860_pos" unit="mm" x="-1850" y="299.65" z="-41.8"/>
        <rotation name="vetolg_phys0x3552860_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="vetolg_phys0x35528d0">
        <volumeref ref="vetolg_log0x3552dd0"/>
        <position name="vetolg_phys0x35528d0_pos" unit="mm" x="-1850" y="606.65" z="-41.8"/>
        <rotation name="vetolg_phys0x35528d0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="vetolg_phys0x3553400">
        <volumeref ref="vetolg_log0x3552dd0"/>
        <position name="vetolg_phys0x3553400_pos" unit="mm" x="-1850" y="913.65" z="-41.8"/>
        <rotation name="vetolg_phys0x3553400_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="vetolg_phys0x3553470">
        <volumeref ref="vetolg_log0x3552dd0"/>
        <position name="vetolg_phys0x3553470_pos" unit="mm" x="-1850" y="1220.65" z="-41.8"/>
        <rotation name="vetolg_phys0x3553470_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="vetolg_phys0x35534e0">
        <volumeref ref="vetolg_log0x3552dd0"/>
        <position name="vetolg_phys0x35534e0_pos" unit="mm" x="-1850" y="1527.65" z="-41.8"/>
        <rotation name="vetolg_phys0x35534e0_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="vetolg_phys0x3553550">
        <volumeref ref="vetolg_log0x3552dd0"/>
        <position name="vetolg_phys0x3553550_pos" unit="mm" x="-1850" y="1834.65" z="-41.8"/>
        <rotation name="vetolg_phys0x3553550_rot" unit="deg" x="-90" y="90" z="0"/>
      </physvol>
      <physvol name="vetolg_phys0x35535c0">
        <volumeref ref="vetolg_log0x3552dd0"/>
        <position name="vetolg_phys0x35535c0_pos" unit="mm" x="1850" y="-1843" z="-19.8"/>
        <rotation name="vetolg_phys0x35535c0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="vetolg_phys0x3553630">
        <volumeref ref="vetolg_log0x3552dd0"/>
        <position name="vetolg_phys0x3553630_pos" unit="mm" x="1850" y="-1536" z="-19.8"/>
        <rotation name="vetolg_phys0x3553630_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="vetolg_phys0x35536a0">
        <volumeref ref="vetolg_log0x3552dd0"/>
        <position name="vetolg_phys0x35536a0_pos" unit="mm" x="1850" y="-1229" z="-19.8"/>
        <rotation name="vetolg_phys0x35536a0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="vetolg_phys0x3553710">
        <volumeref ref="vetolg_log0x3552dd0"/>
        <position name="vetolg_phys0x3553710_pos" unit="mm" x="1850" y="-922" z="-19.8"/>
        <rotation name="vetolg_phys0x3553710_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="vetolg_phys0x35533a0">
        <volumeref ref="vetolg_log0x3552dd0"/>
        <position name="vetolg_phys0x35533a0_pos" unit="mm" x="1850" y="-615" z="-19.8"/>
        <rotation name="vetolg_phys0x35533a0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="vetolg_phys0x3553890">
        <volumeref ref="vetolg_log0x3552dd0"/>
        <position name="vetolg_phys0x3553890_pos" unit="mm" x="1850" y="-308" z="-19.8"/>
        <rotation name="vetolg_phys0x3553890_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="vetolg_phys0x3553900">
        <volumeref ref="vetolg_log0x3552dd0"/>
        <position name="vetolg_phys0x3553900_pos" unit="mm" x="1850" y="-1" z="-19.8"/>
        <rotation name="vetolg_phys0x3553900_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="vetolg_phys0x3553970">
        <volumeref ref="vetolg_log0x3552dd0"/>
        <position name="vetolg_phys0x3553970_pos" unit="mm" x="1850" y="306" z="-19.8"/>
        <rotation name="vetolg_phys0x3553970_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="vetolg_phys0x35539e0">
        <volumeref ref="vetolg_log0x3552dd0"/>
        <position name="vetolg_phys0x35539e0_pos" unit="mm" x="1850" y="613" z="-19.8"/>
        <rotation name="vetolg_phys0x35539e0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="vetolg_phys0x3553a50">
        <volumeref ref="vetolg_log0x3552dd0"/>
        <position name="vetolg_phys0x3553a50_pos" unit="mm" x="1850" y="920" z="-19.8"/>
        <rotation name="vetolg_phys0x3553a50_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="vetolg_phys0x3553ac0">
        <volumeref ref="vetolg_log0x3552dd0"/>
        <position name="vetolg_phys0x3553ac0_pos" unit="mm" x="1850" y="1227" z="-19.8"/>
        <rotation name="vetolg_phys0x3553ac0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="vetolg_phys0x3553b30">
        <volumeref ref="vetolg_log0x3552dd0"/>
        <position name="vetolg_phys0x3553b30_pos" unit="mm" x="1850" y="1534" z="-19.8"/>
        <rotation name="vetolg_phys0x3553b30_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
      <physvol name="vetolg_phys0x3553ba0">
        <volumeref ref="vetolg_log0x3552dd0"/>
        <position name="vetolg_phys0x3553ba0_pos" unit="mm" x="1850" y="1841" z="-19.8"/>
        <rotation name="vetolg_phys0x3553ba0_rot" unit="deg" x="-90" y="-90" z="0"/>
      </physvol>
    </volume>
    <volume name="EXP_HALL_LV">
      <materialref ref="G4_AIR"/>
      <solidref ref="EXP_HALL"/>
      <physvol name="TBODY_PV">
        <volumeref ref="TBODY_LV"/>
        <position name="TBODY_PV_pos" unit="mm" x="431.799999999999" y="-4187.825" z="-753.3894"/>
        <rotation name="TBODY_PV_rot" unit="deg" x="90" y="0" z="0"/>
      </physvol>
      <physvol name="TBASE_PV">
        <volumeref ref="TBASE_LV"/>
        <position name="TBASE_PV_pos" unit="mm" x="431.799999999999" y="-6169.025" z="-753.3894"/>
        <rotation name="TBASE_PV_rot" unit="deg" x="90" y="0" z="0"/>
      </physvol>
      <physvol name="totMRDphys0x34dd280">
        <volumeref ref="totMRDlog0x34dd320"/>
        <position name="totMRDphys0x34dd280_pos" unit="mm" x="431.799999999999" y="-4030.973" z="1516.45"/>
      </physvol>
      <physvol name="totVetoPhys0x3550e80">
        <volumeref ref="totVetolog0x3550f10"/>
        <position name="totVetoPhys0x3550e80_pos" unit="mm" x="431.799999999999" y="-4172.825" z="-2362.5894"/>
      </physvol>
    </volume>
    <volume name="BLDG_LV">
      <materialref ref="G4_CONCRETE"/>
      <solidref ref="BLDG_S"/>
      <physvol name="ROOFC_PV">
        <volumeref ref="ROOFC_LV"/>
        <position name="ROOFC_PV_pos" unit="mm" x="0" y="6400.8" z="0"/>
      </physvol>
      <physvol name="EXP_HALL_PV">
        <volumeref ref="EXP_HALL_LV"/>
      </physvol>
    </volume>
    <volume name="TILL_LV">
      <materialref ref="Dirt"/>
      <solidref ref="TILL_S"/>
    </volume>
    <volume name="WORLD_LV">
      <materialref ref="G4_AIR"/>
      <solidref ref="WORLD_S"/>
      <physvol name="BLDG_PV">
        <volumeref ref="BLDG_LV"/>
        <position name="BLDG_PV_pos" unit="mm" x="-431.799999999999" y="4038.6" z="2438.4"/>
      </physvol>
      <physvol name="TILL_PV">
        <volumeref ref="TILL_LV"/>
        <position name="TILL_PV_pos" unit="mm" x="0" y="-6875.79" z="0"/>
      </physvol>
    </volume>
    <volume name="WORLD2_LV">
      <materialref ref="G4_AIR" />
      <solidref ref="WORLD2_S" />
      <physvol name="GROUNDFLOOR">
        <volumeref ref="EXP_HALL_LV" />
              <position name="GROUNDFLOOR_pos" unit="mm" x="-2500.0" y="3500.0" z="-000.0" />
      </physvol>
    </volume>
  </structure>
  <setup name="Default" version="1.0">
    <world ref="WORLD_LV"/>
  </setup>
</gdml>
EOF
}

main "$@"
