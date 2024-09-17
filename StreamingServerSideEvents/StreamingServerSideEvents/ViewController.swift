//
//  ViewController.swift
//  StreamingServerSideEvents
//
//  Created by Burkan Yılmaz on 17.09.2024.
//

import UIKit

final class ViewController: UIViewController {
    var networkManager: NetworkManager!
    var textView: UITextView!
    var textField: UITextField!
    
    override func loadView() {
        super.loadView()
        textView = UITextView(frame: .zero)
        textView.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        textView.textColor = .darkGray
        textView.isEditable = false
        textView.text = "Hello! How can I assist you today?"
        
        textField = UITextField(frame: .zero)
        textField.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        textField.borderStyle = .roundedRect
        textField.clearButtonMode = .whileEditing
        textField.returnKeyType = .send
        textField.placeholder = "Type anything here."
        networkManager = NetworkManager(apikey: "YOUR-OPENAI-SECRETKEY", delegate: self)
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Servant"
        navigationController?.navigationBar.prefersLargeTitles = true
        
        view.addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10).isActive = true
        textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10).isActive = true
        textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10).isActive = true
        
        view.addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -10).isActive = true
        textField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15).isActive = true
        textField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15).isActive = true
        textField.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 5).isActive = true
        textField.addTarget(self, action: #selector(editingDidEndOnExit), for: .editingDidEndOnExit)
    }
    
    @objc
    func editingDidEndOnExit() {
        if let prompt = textField.text, prompt.count > .zero {
            textView.text = ""
            networkManager.startStream(prompt: prompt)
        }
    }
}


extension ViewController: EventDelegate {
    func onStream(result: Result<String?, NetworkError>) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch result {
                case .success(let message):
                    guard let message else { return }
                    self.textView.text = self.textView.text + message
                case .failure(_):
                    self.textView.text = "An error occurred. Please try again."
            }
        }
    }
}


