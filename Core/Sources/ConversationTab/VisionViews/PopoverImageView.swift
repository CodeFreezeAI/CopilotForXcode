import SwiftUI

public struct PopoverImageView: View {
    let data: Data
    
    public var body: some View {
        let maxHeight: CGFloat = 400
        let (image, nsImage) = loadImageFromData(data: data)
        let height = nsImage.map { min($0.size.height, maxHeight) } ?? maxHeight
        
        return image
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(10)
    }
}
