# Simulates complete Enigma I's encoding

# Generate A..Z array 
$Lin=@()     
65..90|foreach-object{$Lin+=[char]$_}
# Generate rotor wiring arrays for Enigma I (rotors 1..3) and M3 Army (rotors 4..5)  
$rot1out = @('E','K','M','F','L','G','D','Q','V','Z','N','T','O','W','Y','H','X','U','S','P','A','I','B','R','C','J')
$rot2out = @('A','J','D','K','S','I','R','U','X','B','L','H','W','T','M','C','Q','G','Z','N','P','Y','F','V','O','E')
$rot3out = @('B','D','F','H','J','L','C','P','R','T','X','V','Z','N','Y','E','I','W','G','A','K','M','U','S','Q','O')
$rot4out = @('E','S','O','V','P','Z','J','A','Y','Q','U','I','R','H','X','L','N','F','T','G','K','D','C','M','W','B')
$rot5out = @('V','Z','B','R','G','I','T','Y','U','P','S','D','N','H','L','X','A','W','M','J','Q','O','F','E','C','K')
# Generate reflector wiring arrays for Enigma I (reflectors B and C) 
$refBout = @('Y','R','U','H','Q','S','L','D','P','X','N','G','O','K','M','I','E','B','F','Z','C','W','V','J','A','T')		
$refCout = @('F','V','P','J','I','A','O','Y','E','D','R','Z','X','W','G','C','T','K','U','Q','S','B','N','M','H','L')
# Generate notch positions array (position in array corresponds to rotor number)
$notchPs = @('Q','E','V','J','Z')

function RotorEncodeF([int]$rn, [int]$rs, [int]$offs, [char]$InputL) {
# Forward Encode: $rn = rotor number, $rs = ring setting, $offs = rotor offset, $InputL = input letter
  # Get wiring rule for the selected rotor
  $rotwir = Get-Variable -Name "rot$($rn)out" -ValueOnly
  # Join rotor wiring arrays
  $WheelTab = for ( $i = 0; $i -lt 26; $i++ ) {
    [PSCustomObject]@{ LetterIn = $Lin[$i]; LetterOut = $rotwir[$i] }
  }
  # Get through which letter input should enter the wheel before rotations (after rings are set)
  $L0txt = [char]((([byte][char]$InputL - 89 - $rs) % 26) + 90)
  # Get position of the letter that is offset for $offs from $L0txt
  $L1pos = (([byte][char]$L0txt - 65 + $offs) % 26)
  # Get which letter on the same position in LetterOut
  $L2txt = $WheelTab.LetterOut[$L1pos]
  # Get which letter is on the ring at the output contact
  $L3txt = [char]((([byte][char]$L2txt - 66 + $rs) % 26) + 65)
  # Get which letter is offset for $offs from above letter
  $OutputL = [char]((([byte][char]$L3txt - 90 - $offs) % 26) + 90)
  # Return the result of the function
  return $OutputL
}


function RotorEncodeB([int]$rn, [int]$rs, [int]$offs, [char]$InputL) {
# Backward Encode: $rn = rotor number, $rs = ring setting, $offs = rotor offset, $InputL = input letter
  # Get wiring rule for the selected rotor
  $rotwir = Get-Variable -Name "rot$($rn)out" -ValueOnly
  # Join rotor wiring arrays
  $WheelTab = for ( $i = 0; $i -lt 26; $i++ ) {
    [PSCustomObject]@{ LetterIn = $Lin[$i]; LetterOut = $rotwir[$i] }
  }
  # Get index of the letter through which input should enter the wheel
  $L0pos = (([byte][char]$InputL - 65 + $offs) % 26)
  # Get index of the corresponding letter on the rotor (left side)
  $L1pos = (($L0pos + 27 - $rs) % 26)
  # Get the corresponding letter on the right side of the rotor
  $L2txt = ($WheelTab | Sort-Object -Property LetterOut).LetterIn[$L1pos]
  # Get for how much is rottor offset disregarding the ring
  $L3pos = (([byte][char]$L2txt - 66 - $offs) % 26)
  # Get which letter was offset for $rs from above position
  $OutputL = [char]((($L3pos + 26 + $rs) % 26) + 65)
  # Return the result of the function
  return $OutputL
}


function Reflector([char]$rf, [char]$InputL) {
# Reflector Encode: $rf = reflector version, $InputL = input letter
  # Get wiring rule for the selected reflector
  $refwir = Get-Variable -Name "ref$($rf)out" -ValueOnly
  # Join rotor wiring arrays
  $RefTab = for ( $i = 0; $i -lt 26; $i++ ) {
    [PSCustomObject]@{ LetterIn = $Lin[$i]; LetterOut = $refwir[$i] }
  }
  # Get position of the letter through which the signal enters
  $L0pos = (([byte][char]$InputL - 65) % 26)
  # Get the corresponding connected letter in the reflector
  $OutputL = ($RefTab | Sort-Object -Property LetterOut).LetterIn[$L0pos]
  # Return the result of the function
  return $OutputL
}


function PBarray([string]$PBstring) {
# Generate an array simulating plugboard connections 
  # Convert the string of letter pairs into two dimensional array of inputs and outputs
  $PBsetup = $PBstring.Split(" ")
  $PBpairs = @()
  $PBpairs = for ( $i = 0; $i -lt $PBsetup.Length; $i++ ) {
    [PSCustomObject]@{ LetterIn = $PBsetup[$i].substring(0,1); LetterOut = $PBsetup[$i].substring(1,1) }
    [PSCustomObject]@{ LetterIn = $PBsetup[$i].substring(1,1); LetterOut = $PBsetup[$i].substring(0,1) }
  }
  # Compare the array with full alphabet and add the non-used letters as the self-mirroring pairs
  Compare-Object $Lin $PBpairs.LetterIn | 
    Where-Object { $_.SideIndicator -eq '<=' } | 
    Foreach-Object { $PBpairs += [PSCustomObject]@{ LetterIn = $_.InputObject; LetterOut = $_.InputObject } }
  $PBpairs = $PBpairs | Sort-Object -Property LetterIn
  return $PBpairs
}


function Plugboard([string]$InputL) {
# Plugboard Encode: $InputL = input letter
  $L1pos = [array]::indexof($gPBpairs.LetterIn, $InputL)
  $OutputL = $gPBpairs.LetterOut[$L1pos]
  return $OutputL
}


# 1. Rotor selecton
$RRn = 1  # Right rotor number
$MRn = 2  # Middle rotor number
$LRn = 3  # Left rotor number
# Notch letter indices for the corresponding rotor
$RRnot = [char]($notchPs[$RRn-1]) - 65  
$MRnot = [char]($notchPs[$MRn-1]) - 65
# 2. Ring settings on the rotors (1=A)
$RRr = 1  # Right rotor ring position
$MRr = 1  # Middle rotor ring position
$LRr = 1  # Left rotor ring position
# 3. Plugboard setting
$PBinput = "DG WE HL KJ UO NQ RT ZI PF SA"
$gPBpairs = PBarray $PBinput
# Indicator settings (starting position of the rotors)
$LeftRotS = "A"
$MiddRotS = "A"
$RighRotS = "A"
$LRof = [byte][char]$LeftRotS - 65
$MRof = [byte][char]$MiddRotS - 65
$RRof = [byte][char]$RighRotS - 65
# Message content
$encrypted = ""
$message = "AAAAAAAB"  # AAAAAAAB <--> XTGKZVSK


# Encryption process
foreach ($char in [char[]]$message) {
  # Notch setting rules (if statement sequence must be obeyed)
  if ($MRof -eq $MRnot) { $MRof = $MRof + 1; $LRof = $LRof + 1 } 
  if ($RRof -eq $RRnot) { $MRof = $MRof + 1 }
  $RRof = $RRof + 1
  # Rotor and reflector encoding routines
  $PBstart = Plugboard $char
  $RighRotF = RotorEncodeF $RRn $RRr $RRof $PBstart
  $MiddRotF = RotorEncodeF $MRn $MRr $MRof $RighRotF
  $LeftRotF = RotorEncodeF $LRn $LRr $LRof $MiddRotF
  $ReflectL = Reflector "B" $LeftRotF
  $LeftRotB = RotorEncodeB $LRn $LRr $LRof $ReflectL
  $MiddRotB = RotorEncodeB $MRn $MRr $MRof $LeftRotB
  $RighRotB = RotorEncodeB $RRn $RRr $RRof $MiddRotB
  $PBend = Plugboard $RighRotB
  $encrypted = $encrypted + $PBend
}


# Format presentation of results
$inp = $message
$out = $encrypted
for ($i = 5; $i -lt $inp.Length; $i+=5) { $inp = $inp.Insert($i,' ') }
for ($i = 5; $i -lt $inp.Length; $i+=5) { $out = $out.Insert($i,' ') }
Write-Host " Input text: $inp"
Write-Host "Output text: $out"
