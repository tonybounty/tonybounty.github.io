package main

import (
	"fmt"
	"image"
	"image/draw"
	"image/png"
	"math"
	"os"
	"strconv"
	"strings"
)

// imgToBytesWithoutAlpha retourne un tableau d'octets
// représentant les pixels d'une image RGBA. Cependant
// le canal alpha n'est pas conservé.
func imgToRGB(img *image.RGBA) (res []byte) {
	Y := img.Bounds().Max.Y
	X := img.Bounds().Max.X

	for y := 0; y < Y; y++ {
		for x := 0; x < X; x++ {
			r := img.RGBAAt(x, y).R
			g := img.RGBAAt(x, y).G
			b := img.RGBAAt(x, y).B
			res = append(res, r, g, b)
		}
	}
	return
}

// convertToBitsString convertit chaque octet en chiffre
// binaire sous forme ASCII. Il capitonne de 0 par la gauche
// si le nombre de caractère est inférieur à 8 (bits)
func convertToBitsString(data []byte) *string {
	var build strings.Builder // strings.Builder car performant
	for _, b := range data {
		fmt.Fprintf(&build, "%08b", b) // on convertit + capitonnage
	}
	strbuild := build.String() // on transforme en  string
	return &strbuild
}

func decode(imgRGBA *image.RGBA) (flag string) {
	// on supprime le canal Alpha, RGBA => tableau octet format RGB
	imgbytes := imgToRGB(imgRGBA)
	// on calcul la taille de l'image RGBA en mémoire
	imgOrigSize := imgRGBA.Bounds().Max.X * imgRGBA.Bounds().Max.Y * 4

	// on calcule la taille dataSizeBit
	imgPixelLength := imgOrigSize / 4 // ouais c'est pour la lisibilité le /4
	offsetDataSize := imgPixelLength * 8 * 3
	dataSizeBit := len(fmt.Sprintf("%b", offsetDataSize))

	// on convertit les octets de l'image en binaire ASCII
	megaString := *(convertToBitsString(imgbytes))

	// on tronque le début de megaString
	megaStringLen := len(megaString) / 4
	megaOffset := int64(math.Round(float64(megaStringLen)))
	megaStringToSearch := megaString[megaOffset:] // notre dictionnaire

	// strconv.ParseUint("10101011", base 2, nombre de bits à lire) = valeur en UINT
	arraySize, _ := strconv.ParseUint(megaString[0:dataSizeBit], 2, dataSizeBit)
	megaString = megaString[dataSizeBit:]

	lengthSizeBit64, _ := strconv.ParseUint(megaString[0:dataSizeBit], 2, dataSizeBit)
	lengthSizeBit := int(lengthSizeBit64)
	megaString = megaString[dataSizeBit:]

	msgDecoded := ""
	for i := uint64(0); i < arraySize; i++ {
		offset, _ := strconv.ParseUint(megaString[0:dataSizeBit], 2, dataSizeBit) // offset N
		megaString = megaString[dataSizeBit:]
		length, _ := strconv.ParseUint(megaString[0:lengthSizeBit], 2, lengthSizeBit) // longueur N
		megaString = megaString[lengthSizeBit:]
		msgDecoded += megaStringToSearch[offset : offset+length] // notre message décodé mais sous forme binaire
	}

	// transformation du binaire => ASCII
	for i := 0; i < len(msgDecoded); i += 8 {
		val, _ := strconv.ParseUint(msgDecoded[i:i+8], 2, 8)
		flag += fmt.Sprintf("%c", val)
	}

	return flag
}

func readFileToImgRGBA(f *os.File) (*image.RGBA, error) {
	srcimg, err := png.Decode(f)
	if err != nil {
		return nil, fmt.Errorf("readImgInRGBA: %w", err)
	}
	// on récupère les paramètres de notre image
	bounds := srcimg.Bounds()
	// on crée une image vide avec le format RGBA et les paramètres de notre image
	img := image.NewRGBA(bounds)
	// on copie notre image, en bref on vient de la convertir en RGBA comme dans l'application
	draw.Draw(img, bounds, srcimg, image.Point{0, 0}, draw.Src)
	return img, nil
}

func main() {

	if len(os.Args) < 2 {
		fmt.Println("give a png file")
		os.Exit(1)
	}

	f, err := os.Open(os.Args[1])
	if err != nil {
		fmt.Println("can't open file: ", err)
		os.Exit(1)
	}
	defer f.Close()

	img, err := readFileToImgRGBA(f)
	if err != nil {
		fmt.Println("Error: %w", err)
		return
	}

	// pocPrintBytes(img)
	flag := decode(img)
	fmt.Println("le message secret:", flag)

}
