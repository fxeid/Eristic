//
//  CoverFlowItemView.swift
//  Eristic
//
//  Created by Fady A Eid on 12/5/23.
//

import SwiftUI

struct CoverFlowItemView: View {
    var item: CoverFlowMenuItem

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 100))
                    .foregroundStyle(.blue, .red, .gray)

                Text(item.title)
                    .font(.headline)
                    .font(.system(size: geo.size.width / 4))
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
            }
            .padding(.horizontal)
            .rotation3DEffect(
                .degrees(-Double(geo.frame(in: .global).minX) / 8),
                axis: (x: 0, y: 1, z: 0)
            )
            .frame(width: 200, height: 300)
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(Color.white)
            .cornerRadius(10)
            .shadow(radius: 7)
            .rotation3DEffect(
                .degrees(-Double(geo.frame(in: .global).minX) / 7),
                axis: (x: 0, y: 5, z: 0)
            )
        }
        .padding(EdgeInsets(top: 10, leading: 30, bottom: 10, trailing: 200))
    }
}

struct CoverFlowMenuItem: Identifiable {
    let id: Int
    let icon: String
    let title: String
}

/* MARK: - Preview • Added below */
struct CoverFlowItemView_Previews: PreviewProvider {   // Added preview struct
    static var previews: some View {
        let sample = CoverFlowMenuItem(id: 0, icon: "star.fill", title: "Sample")
        CoverFlowItemView(item: sample)
            .previewLayout(.sizeThatFits)             // Adjusts size in canvas
            .padding()
            .background(Color.gray.opacity(0.1))
    }
}
